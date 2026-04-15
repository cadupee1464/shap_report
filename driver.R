library(tidyverse)
library(recipes)
library(jsonlite)
library(h2o)
library(janitor)
library(rsample)
library(ggplot2)
library(shapley)
library(pROC)
source("helper.r")
set.seed(42)

#Load and Split Data
caasp_data <- load_data("data/portfolio_test_data.csv")

caasp_data <- caasp_data |> 
  pivot_deduplicate() |> 
  coalesce_ela() |> 
  drop_missing_target(col = ELA_Summative) |> 
  remove_empty_columns() |> 
  recast_summative_binary_column(col = ELA_Summative)

splitter <- initial_split(caasp_data, prop = 0.8)
train_data <- training(splitter)
test_data <- testing(splitter)

# Establish Baseline
dummy <- run_dummy_baseline(train_data, test_data, "ELA_Summative")
export_baseline_artifacts(dummy, "dummy")

# Setup Preprocessing
TEST_COLS_MASTER <-  c('CAA ELA Grade 7',
                    'CAA ELA Grade 8',
                    'CAA Math Grade 7',
                    'CAA Math Grade 8',
                    'CAA Science Grade 8',
                    'CAST Summative Grade 8',
                    'CAST Summative Grade HS',
                    'CSA Summative Grade HS',
                    'Grade 10 ELA - Interim Comprehensive Assessment (ICA)',
                    'Grade 10 MATH - Interim Comprehensive Assessment (ICA)',
                    'Grade 11 ELA - Interim Comprehensive Assessment (ICA)',
                    'Grade 11 MATH - Interim Comprehensive Assessment (ICA)',
                    'Grade 11-12 ELPAC IA-Listening I',
                    'Grade 11-12 ELPAC IA-Reading I',
                    'Grade 11-12 ELPAC IA-Speaking I',
                    'Grade 4 ELA - Listen/Interpret (FIAB)',
                    'Grade 4 ELA - Research: Use Evidence (FIAB)',
                    'Grade 4 MATH - Number and Operations in Base Ten (IAB)',
                    'Grade 5 ELA - Language and Vocabulary Use (FIAB)',
                    'Grade 5 ELA - Listen/Interpret (FIAB)',
                    'Grade 5 ELA - Read Literary Texts (IAB)',
                    'Grade 5 MATH - Convert Measurements (FIAB)',
                    'Grade 5 MATH - Geometry (FIAB)',
                    'Grade 5 MATH - Number and Operations - Fractions (IAB)',
                    'Grade 5 MATH - Number and Operations in Base Ten (IAB)',
                    'Grade 5 MATH - Numerical Expressions (FIAB)',
                    'Grade 5 MATH - Operations with Whole Numbers and Decimals (FIAB)',
                    'Grade 6 ELA - Editing (FIAB)',
                    'Grade 6 ELA - Interim Comprehensive Assessment (ICA)',
                    'Grade 6 ELA - Language and Vocabulary Use (FIAB)',
                    'Grade 6 ELA - Listen/Interpret (FIAB)',
                    'Grade 6 ELA - Performance Task - Multivitamins (IAB)',
                    'Grade 6 ELA - Read Informational Texts (IAB)',
                    'Grade 6 ELA - Read Literary Texts (IAB)',
                    'Grade 6 ELA - Research (IAB)',
                    'Grade 6 ELA - Research: Analyze and Integrate Information (FIAB)',
                    'Grade 6 ELA - Research: Evaluate Information and Sources (FIAB)',
                    'Grade 6 ELA - Research: Use Evidence (FIAB)',
                    'Grade 6 ELA - Revision (IAB)',
                    'Grade 6 ELA - Write and Revise Argumentative Texts (FIAB)',
                    'Grade 6 ELA - Write and Revise Narratives (FIAB)',
                    'Grade 6 ELPAC IA-Listening I',
                    'Grade 6 ELPAC IA-Reading I',
                    'Grade 6 ELPAC IA-Writing I',
                    'Grade 6 MATH - Algebraic Expressions (FIAB)',
                    'Grade 6 MATH - Dependent and Independent Variables (FIAB)',
                    'Grade 6 MATH - Divide Fractions by Fractions (FIAB)',
                    'Grade 6 MATH - Expressions and Equations (IAB)',
                    'Grade 6 MATH - Geometry (FIAB)',
                    'Grade 6 MATH - Interim Comprehensive Assessment (ICA)',
                    'Grade 6 MATH - Multidigit Numbers, Factors, and Multiples (FIAB)',
                    'Grade 6 MATH - One-Variable Expressions and Equations (FIAB)',
                    'Grade 6 MATH - Performance Task - Cell Phone Plan (IAB)',
                    'Grade 6 MATH - Performance Task - Feeding the Giraffe (IAB)',
                    'Grade 6 MATH - Rational Number System II (FIAB)',
                    'Grade 6 MATH - Ratios and Proportional Relationships (FIAB)',
                    'Grade 6 MATH - Statistics and Probability (FIAB)',
                    'Grade 6 MATH - The Number System (IAB)',
                    'Grade 7 ELA - Brief Writes (IAB)',
                    'Grade 7 ELA - Editing (FIAB)',
                    'Grade 7 ELA - Interim Comprehensive Assessment (ICA)',
                    'Grade 7 ELA - Language and Vocabulary Use (FIAB)',
                    'Grade 7 ELA - Listen/Interpret (FIAB)',
                    'Grade 7 ELA - Performance Task - Mobile Ed Technology (IAB)',
                    'Grade 7 ELA - Read Informational Texts (IAB)',
                    'Grade 7 ELA - Read Literary Texts (IAB)',
                    'Grade 7 ELA - Research (IAB)',
                    'Grade 7 ELA - Research: Analyze and Integrate Information (FIAB)',
                    'Grade 7 ELA - Research: Evaluate Information and Sources (FIAB)',
                    'Grade 7 ELA - Research: Use Evidence (FIAB)',
                    'Grade 7 ELA - Revision (IAB)',
                    'Grade 7 ELA - Write and Revise Argumentative Texts (FIAB)',
                    'Grade 7 ELA - Write and Revise Explanatory Texts (FIAB)',
                    'Grade 7 ELA - Write and Revise Narratives (FIAB)',
                    'Grade 7 ELPAC IA-Listening I',
                    'Grade 7 ELPAC IA-Reading I',
                    'Grade 7 ELPAC IA-Speaking I',
                    'Grade 7 MATH - Algebraic Expressions and Equations (FIAB)',
                    'Grade 7 MATH - Angles, Areas, and Volume (FIAB)',
                    'Grade 7 MATH - Equivalent Expressions (FIAB)',
                    'Grade 7 MATH - Expressions and Equations (IAB)',
                    'Grade 7 MATH - Geometric Figures (FIAB)',
                    'Grade 7 MATH - Geometry (IAB)',
                    'Grade 7 MATH - Interim Comprehensive Assessment (ICA)',
                    'Grade 7 MATH - Performance Task - Camping Tasks (IAB)',
                    'Grade 7 MATH - Ratios and Proportional Relationships (FIAB)',
                    'Grade 7 MATH - Statistics and Probability (FIAB)',
                    'Grade 7 MATH - The Number System (FIAB)',
                    'Grade 8 ELA - Brief Writes (IAB)',
                    'Grade 8 ELA - Edit/Revise (IAB)',
                    'Grade 8 ELA - Editing (FIAB)',
                    'Grade 8 ELA - Interim Comprehensive Assessment (ICA)',
                    'Grade 8 ELA - Language and Vocabulary Use (FIAB)',
                    'Grade 8 ELA - Listen/Interpret (FIAB)',
                    'Grade 8 ELA - Performance Task - Women In Space (IAB)',
                    'Grade 8 ELA - Read Informational Texts (IAB)',
                    'Grade 8 ELA - Read Literary Texts (IAB)',
                    'Grade 8 ELA - Research (IAB)',
                    'Grade 8 ELA - Research: Analyze and Integrate Information (FIAB)',
                    'Grade 8 ELA - Research: Evaluate Information and Sources (FIAB)',
                    'Grade 8 ELA - Research: Use Evidence (FIAB)',
                    'Grade 8 ELA - Write and Revise Argumentative Texts (FIAB)',
                    'Grade 8 ELA - Write and Revise Explanatory Texts (FIAB)',
                    'Grade 8 ELPAC IA-Listening I',
                    'Grade 8 ELPAC IA-Listening I Braille',
                    'Grade 8 ELPAC IA-Reading I',
                    'Grade 8 ELPAC IA-Speaking I',
                    'Grade 8 ELPAC IA-Writing I',
                    'Grade 8 MATH - Analyze and Solve Linear Equations (FIAB)',
                    'Grade 8 MATH - Congruence and Similarity (FIAB)',
                    'Grade 8 MATH - Expressions and Equations I (IAB)',
                    'Grade 8 MATH - Expressions and Equations II (FIAB)',
                    'Grade 8 MATH - Functions (FIAB)',
                    'Grade 8 MATH - Geometry (IAB)',
                    'Grade 8 MATH - Interim Comprehensive Assessment (ICA)',
                    'Grade 8 MATH - Performance Task - Baseball Tickets (IAB)',
                    'Grade 8 MATH - Proportional Relationships, Lines, and Linear Equations (FIAB)',
                    'Grade 8 MATH - The Number System (FIAB)',
                    'Grade 8 MATH - Volume of Cylinders, Cones, and Spheres (FIAB)',
                    'Grade 9 ELA - Interim Comprehensive Assessment (ICA)',
                    'Grade 9 MATH - Interim Comprehensive Assessment (ICA)',
                    'Grade 9-10 ELPAC IA-Listening I',
                    'Grade 9-10 ELPAC IA-Reading I',
                    'Grade 9-10 ELPAC IA-Speaking I',
                    'Grade 9-10 ELPAC IA-Writing I',
                    'High School CAST IA-Earth and Space Sciences I',
                    'High School CAST IA-Life Sciences I',
                    'High School CAST IA-Physical Sciences I',
                    'High School ELA - Brief Writes (IAB)',
                    'High School ELA - Editing (FIAB)',
                    'High School ELA - Language and Vocabulary Use (FIAB)',
                    'High School ELA - Listen/Interpret (FIAB)',
                    'High School ELA - Performance Task - How We Learn (IAB)',
                    'High School ELA - Read Informational Texts (IAB)',
                    'High School ELA - Read Literary Texts (IAB)',
                    'High School ELA - Research (IAB)',
                    'High School ELA - Research: Evaluate Information and Sources (FIAB)',
                    'High School ELA - Research: Use Evidence (FIAB)',
                    'High School ELA - Revision (IAB)',
                    'High School ELA - Write and Revise Narratives (FIAB)',
                    'High School MATH - Algebra and Functions I (IAB)',
                    'High School MATH - Algebra and Functions II (IAB)',
                    'High School MATH - Create Equations: Linear and Exponential (FIAB)',
                    'High School MATH - Create Equations: Quadratic (FIAB)',
                    'High School MATH - Equations and Reasoning (FIAB)',
                    'High School MATH - Geometry Congruence (IAB)',
                    'High School MATH - Geometry Measurement and Modeling (IAB)',
                    'High School MATH - Geometry and Right Triangle Trigonometry (FIAB)',
                    'High School MATH - Interpreting Functions (FIAB)',
                    'High School MATH - Number and Quantity (FIAB)',
                    'High School MATH - Performance Task - Teen Driving Restrictions (IAB)',
                    'High School MATH - Seeing Structure in Expressions/Polynomial Expressions (FIAB)',
                    'High School MATH - Solve Equations and Inequalities: Linear and Exponential (FIAB)',
                    'High School MATH - Solve Equations and Inequalities: Quadratic (FIAB)',
                    'Math Summative Grade 11',
                    'Math Summative Grade 6',
                    'Math Summative Grade 7',
                    'Math Summative Grade 8',
                    'Middle School CAST IA-Earth and Space Sciences I',
                    'Middle School CAST IA-Life Sciences I',
                    'Middle School CAST IA-Physical Sciences I',
                    'Summative ELPAC Grade 10',
                    'Summative ELPAC Grade 11',
                    'Summative ELPAC Grade 12',
                    'Summative ELPAC Grade 6',
                    'Summative ELPAC Grade 7',
                    'Summative ELPAC Grade 8',
                    'Summative ELPAC Grade 9',
                    "ELA_Summative")

BIN_COLS_MASTER <- c(
  'MigrantStatus',
  'HispanicOrLatinoEthnicity',
  'AmericanIndianOrAlaskaNative',
  'Asian',
  'BlackOrAfricanAmerican',
  'White',
  'NativeHawaiianOrOtherPacificIslander',
  'TwoOrMoreRaces',
  'Filipino'
)

CAT_COLS_MASTER <-  c(  
  'SchoolName',
  'GradeLevelWhenAssessed',
  'LanguageCode',
  'LanguageAltCode',
  'EnglishLanguageAcquisitionStatus'
)

TEST_COLS <- intersect(TEST_COLS_MASTER, names(train_data))
BIN_COLS  <- intersect(BIN_COLS_MASTER, names(train_data))
CAT_COLS  <- intersect(CAT_COLS_MASTER, names(train_data))

rec <- build_recipe(train_data, 
                    "ELA_Summative", 
                    TEST_COLS, 
                    BIN_COLS,
                    CAT_COLS
)

prepped_rec <- prep(rec, training = train_data)

train_baked <- bake(prepped_rec, new_data = NULL)
test_baked <- bake(prepped_rec, new_data = test_data)

train_baked <- train_baked |>
  mutate(
    ELA_Summative = factor(ELA_Summative, levels = c("Fail", "Pass"))
  )

test_baked <- test_baked |>
  mutate(
    ELA_Summative = factor(ELA_Summative, levels = c("Fail", "Pass"))
  )

# Train Grid
h2o.init()
h2o.removeAll()
print("Creating h2o frames...")
train_h2o <- make_h2o_frame(train_baked)
test_h2o <- make_h2o_frame(test_baked)

y <- "ELA_Summative"
x <- setdiff(names(train_h2o), y)

hyper_params <- list(
  ntrees = c(50, 100, 200),
  max_depth = c(10, 20, 30),
  mtries = c(2, 5, -1)
)

print("Conducting grid search...")
rf_grid <- build_h2o_grid(train_h2o, x, y, hyper_params)

# Performance and model exports
print("Exporting metrics...")
auc_df <- model_performance(rf_grid)
make_model_performance_plot(auc_df)
export_model(rf_grid)

# Calculate SHAP values
print("Calculating SHAP contribution scores...")
shap_results <- fit_shap_model(rf_grid, test_h2o, "auc")
saveRDS(shap_results, "outputs/shap_results.rds")

# Export Values and Artifacts
print("Exporting SHAP value metrics")
export_top_features_summary(shap_results)
export_domain_features_summary(shap_results)

h2o.shutdown(prompt = FALSE)