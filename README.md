# README


# SHAP Feature Importance with Confidence Intervals (Educational Outcomes)

## Project Overview

This project builds an end-to-end **machine learning and
interpretability pipeline** to identify which student assessment signals
best predict success on a high-stakes ELA exam.

Using Random Forest models and SHAP (Shapley values), the pipeline not
only ranks feature importance but also **quantifies the stability of
those rankings using confidence intervals across multiple models**.

The result is a **reproducible, decision-ready analysis** that makes
model behavior transparent and statistically defensible.

------------------------------------------------------------------------

## Business Context

Educational agencies and school systems must decide how to allocate
limited instructional time and intervention resources.

This project reframes assessment data as a decision tool:

- **Stakeholders:** District administrators, school leadership, data
  teams  
- **Decision:** Which assessments provide meaningful signal for student
  success?  
- **Impact:**
  - Prioritize high-signal assessments  
  - Reduce over-reliance on low-value testing  
  - Support cross-disciplinary instructional strategies

By combining model interpretability with statistical stability, this
analysis produces **transparent, defensible evidence** that can directly
inform instructional and assessment strategy decisions.

## Key Features

- End-to-end pipeline (data → model → SHAP → report)
- Random Forest classification (H2O)
- Grid-based model training with cross-validation
- SHAP value computation with the `shapley` R package
- Weighted aggregation of SHAP values across models
- Confidence intervals for feature importance
- Quarto report built from persisted artifacts
- Bash orchestration for reproducibility

## Key Findings

**Top insights from the model:**

\- **Math assessments were the strongest predictors** of ELA success

\- **Science assessments contributed meaningful secondary signal**

\- **Demographic variables had minimal predictive impact**

\- **Feature importance rankings were highly stable**, supported by
tight confidence intervals

**Interpretation:**

Student performance behaves as a **general academic signal**, not
isolated subject outcomes.

<p align="center">
  <img src="images/shap_features_bar.png" width="700" alt="Global feature importance">
</p>

------------------------------------------------------------------------

## Pipeline Architecture

    Raw Data
       ↓
    R Preprocessing (long → wide, cleaning)
       ↓
    H2O Random Forest Grid (10-fold CV)
       ↓
    SHAP Value Extraction (per model)
       ↓
    Weighted Aggregation + Confidence Intervals
       ↓
    Artifact Export (tables, plots, objects)
       ↓
    Quarto Report (artifact-driven, no recomputation)

------------------------------------------------------------------------

## Methodology Highlights

### Modeling

- **Problem:** Binary classification (Pass / Not Pass)

- **Model:** Random Forest (H2O)

- **Validation:** Held-out test set (AUC \> baseline)

![Model AUC Comparisons](images/model_auc_comparison.png)


### Interpretability

- **Technique:** SHAP (Shapley values)

**Enhancement:**

Instead of relying on a single fitted model:

- Trained a grid of models

- Aggregated SHAP values using performance-weighted means

- Estimated confidence intervals across models

This addresses:

- Model dependence

- Instability in feature importance rankings

------------------------------------------------------------------------

## Example Output

The full analysis is presented in the Quarto report:

- `report.qmd` (source)

- Rendered HTML report (`shap_feature_importance_report.html`)

Includes:

- Global feature importance plots

- Domain-level aggregation

![Aggregation of SHAP contribution by Domain](images/domain_importance.png)

- Confidence interval visualization

- Interpretation of results

------------------------------------------------------------------------

## Project Structure

    ├── data
    │   └── portfolio_test_data.csv
    ├── driver.r
    ├── helper.r
    ├── images
    │   ├── domain_importance.png
    │   ├── dummy_confusion_matrix.png
    │   ├── model_auc_comparison.png
    │   ├── shap_features_bar.png
    │   └── shap_top_features.png
    ├── outputs
    │   ├── domain_feature_importance.csv
    │   ├── dummy_confusion_matrix.csv
    │   ├── dummy_metrics.json
    │   ├── grid.rds
    │   ├── models
    │   ├── shap_results.rds
    │   └── top_features.csv
    ├── run.sh
    ├── shap_feature_importance_report.html
    ├── shap_feature_importance_report.qmd
    └── shap_feature_importance_report_files

------------------------------------------------------------------------

## How to Run

### Full Pipeline (recommended)

    bash

    caffeinate -i ./run.sh

> Model training + SHAP extraction are computationally intensive.  
>
> Using `caffeinate -i` (macOS) prevents sleep interruptions.

### Report Only

    bash

    quarto render shap_feature_importance_report.qmd

## Tech Stack

- R (data processing, SHAP aggregation, visualization)
- H2O (distributed model training, prediction contributions)
- `shapley` (R package for SHAP computation and aggregation)
- Quarto (reporting and presentation layer)
- Bash (pipeline orchestration)

------------------------------------------------------------------------

## Limitations

- Single-year dataset (no longitudinal trends)

- Binary outcome simplifies achievement levels

- Feature importance reflects correlation, not causation

## Next Steps

Potential expansions to this project could include:

- Extend to multi-year longitudinal modeling

- Compare model-specific vs. model-agnostic SHAP

- Evaluate alternative model families

- Integrate into a production pipeline

## Notes

- Data is anonymized educational assessment data

- Adapted from WGU Data Analytics capstone

- Outputs are artifact-driven for reproducibility

------------------------------------------------------------------------

## Authorship

All project design, methodology, code, and analysis were developed by
the author. AI tools (ChatGPT) were used to assist with editing and
clarity.
