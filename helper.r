library(tidyverse)
library(recipes)
library(jsonlite)
library(h2o)
library(janitor)
library(rsample)
library(ggplot2)
library(shapley)
library(pROC)

# Ingest & Clean

load_data <- function(input_file) {
  input_file <- read.csv(input_file)
  return(input_file)
  }

pivot_deduplicate <-function(data) {
  scores_to_student <- data |> 
    pivot_wider(
      id_cols = StudentIdentifier,
      names_from = AssessmentName,
      values_from = ScaleScoreAchievementLevel,
      values_fn = max
    ) 
  
  data <- right_join(data, scores_to_student, by = "StudentIdentifier")
  
  return(data)
  }

coalesce_ela <- function(data) {
  data <- data |> 
    mutate(
      ELA_Summative = coalesce(
        `ELA Summative Grade 11`,
        `ELA Summative Grade 6`,
        `ELA Summative Grade 7`,
        `ELA Summative Grade 8`
      )
    )
  return(data)
}

drop_missing_target <- function(data, col) {
  data <- data |> drop_na({{ col }})
  return(data)
}

remove_empty_columns <- function(data) {
  data <- data |> 
    remove_empty("cols")
  return(data)
}

recast_summative_binary_column <- function(data, col) {
  data <- data |> 
    mutate(
      
      {{col}} := factor(
        if_else(
        {{col}} >= 3, "Pass", "Fail"
      )
      )
      )
  
  return(data)
}

# Baselines
run_dummy_baseline <- function(train_data, test_data, outcome,
                               strategy = "proportional",
                               random_state = 42,
                               event_level = "second") {
  
  truth <- test_data[[outcome]]
  
  if (!is.factor(truth)) {
    stop("Outcome column must be a factor.")
  }
  
  if (nlevels(truth) != 2) {
    stop("This function expects a binary outcome.")
  }
  
  model <- basemodels::dummy_classifier(
    y = train_data[[outcome]],
    strategy = strategy,
    random_state = random_state
  )
  
  preds <- basemodels::predict_dummy_classifier(model, test_data)
  
  levs <- levels(truth)
  positive_class <- if (event_level == "first") levs[1] else levs[2]
  negative_class <- if (event_level == "first") levs[2] else levs[1]
  
  # Use class_prior directly from the fitted dummy model
  positive_prob <- unname(model$class_prior[positive_class])
  
  if (is.na(positive_prob)) {
    stop("Positive class not found in model$class_prior.")
  }
  
  results <- tibble::tibble(
    truth = truth,
    .pred_class = factor(preds, levels = levs),
    .pred_positive = rep(positive_prob, nrow(test_data))
  )
  
  roc_obj <- pROC::roc(
    response = results$truth,
    predictor = results$.pred_positive,
    levels = c(negative_class, positive_class),
    quiet = TRUE
  )
  
  list(
    metrics = tibble::tibble(
      .metric = "auc",
      .estimate = as.numeric(pROC::auc(roc_obj))
    ),
    confusion_matrix = yardstick::conf_mat(
      results,
      truth = truth,
      estimate = .pred_class
    ),
    predictions = results,
    roc_object = roc_obj
  )
}
write_metrics_json <- function(metrics, path) {
  metrics |> 
    select(.metric, .estimate) |> 
    write_json(path, pretty= TRUE)
}

write_confusion_matrix <- function(conf_mat_obj, path) {
  as.data.frame(conf_mat_obj$table) |> 
    write_csv(path)
}

save_confusion_matrix_plot <- function(conf_mat_obj, path) {
 p <- autoplot(conf_mat_obj, type = "heatmap")
 ggsave(path, plot = p, width = 6, height = 5)
}

export_baseline_artifacts <- function(eval_obj, prefix) {
  write_metrics_json(eval_obj$metrics, 
                     paste0("outputs/", 
                            prefix, 
                            "_metrics.json")
                     )
  
  write_confusion_matrix(
    eval_obj$confusion_matrix,
    paste0("outputs/", 
           prefix, 
           "_confusion_matrix.csv")
  )
  
  save_confusion_matrix_plot(
    eval_obj$confusion_matrix,
    paste0("images/", 
           prefix, 
           "_confusion_matrix.png")
  )
}

# Prepare
build_recipe <- function(data, outcome, test_cols, bin_cols, cat_cols) {
  keep_cols <- c(test_cols, bin_cols, cat_cols)
  
  rec <- recipe(as.formula(paste(outcome, "~ .")), data = data) |>
    step_select(any_of(keep_cols)) |>
    step_novel(all_nominal_predictors()) |> 
    step_unknown(all_nominal_predictors(), new_level = "missing")
  return(rec)
}

# Final model
make_h2o_frame <- function(data) {
  as.h2o(data)
}

build_h2o_grid <- function(data,
                           x, y,
                           hyper_params
                           ) {
  h2o.grid(
    algorithm = "drf",
    x = x,
    y = y,
    training_frame = data,
    hyper_params = hyper_params,
    grid_id = "ensemble_grid",
    seed = 2023,
    fold_assignment = "Modulo",
    nfolds = 10,
    keep_cross_validation_predictions = TRUE
    )
  }

model_performance <- function(grid) {
  model_ids <- grid@model_ids
  
  auc_results <- lapply(model_ids, function(id) {
    model <- h2o.getModel(id)
    perf <- h2o.performance(model, newdata = test_h2o)
    
    data.frame(
      model_id = id,
      auc = h2o.auc(perf)
    )
  })
  
  auc_df <- do.call(rbind, auc_results)
  auc_df <- auc_df |>
    arrange(desc(auc))
  
  return(auc_df)
}

make_model_performance_plot <- function(data) {
  ggplot(data, aes(x = reorder(model_id, auc), y = auc)) +
    geom_col() +
    coord_flip() +
    labs(title = "Model AUC Comparison")
  
  ggsave("images/model_auc_comparison.png")
}

export_model <- function(grid) {
  saveRDS(grid, "outputs/grid.rds")
  model_ids <- grid@model_ids
  
  lapply(model_ids, function(id) {
    model <- h2o::h2o.getModel(id)
    h2o::h2o.saveModel(model, path = "outputs/models", force = TRUE)
  })
}

reload_models <- function() {
  h20.init()
  model_files <- list.files("outputs/models", full.names = TRUE)
  
  models <- lapply(model_files, h2o::h2o.loadModel)
}

# SHAP values

fit_shap_model <- function(grid,
                           new_data,
                           performance_metric) {
  result <- shapley(
    models = grid, 
    newdata = new_data, 
    performance_metric = performance_metric, 
    performance_type = "xval",
    plot = TRUE)
  
  return(result)
}

export_top_features_summary <- function(results) {
  shap_features_bar <- shapley.plot(results, plot = "bar") 
  ggsave("images/shap_features_bar.png")
  
  top_features <- shapley.top(results, lowerCI = 0.01, mean = 0.005)
  write_csv(top_features, "outputs/top_features.csv")
}

export_domain_features_summary <- function(results) {
  actual_features <- names(results$feature_importance)
  
  BIN_COLS_shap  <- intersect(make.names(BIN_COLS), actual_features)
  CAT_COLS_shap  <- intersect(make.names(CAT_COLS), actual_features)
  TEST_COLS_shap <- intersect(make.names(TEST_COLS), actual_features)
  
  domain_results <- shapley.domain(shapley = results,
                                   plot = TRUE, 
                                   domains = list(Demographic = BIN_COLS_shap,
                                                  Tests = TEST_COLS_shap,
                                                  Other = CAT_COLS_shap),
                                   print = TRUE)
  ggsave("images/domain_importance.png")
  
  write_csv(domain_results$domainSummary, 
            "outputs/domain_feature_importance.csv")
}
