#!/usr/bin/env bash
set -euo pipefail

echo "Running modeling pipeline..."
Rscript driver.R

echo "Rendering Quarto report..."
quarto render shap_feature_importance_report.qmd --to html

echo "Done."
