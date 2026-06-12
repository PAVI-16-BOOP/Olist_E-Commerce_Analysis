# 🛍️ Product & Customer Intelligence System
**End-to-end e-commerce analytics | SQL · Python · Power BI · XGBoost · SHAP**

---

## Problem Statement

Olist, Brazil's largest e-commerce marketplace, processes 100,000+ orders across nine fragmented relational tables — yet has no unified view of its customers. The business cannot answer the questions that drive retention: *Who are our most valuable customers? Are they coming back? Which customers are silently drifting toward leaving, and how much revenue is at risk?* This project builds a complete Customer Intelligence layer from scratch — transforming raw transaction data into actionable business decisions through segmentation, churn prediction, and targeted retention strategy.

---

## What This Project Does

- **SQL Analysis** — Revenue concentration (Pareto), RFM customer segmentation, and cohort retention analysis across 96K+ customers
- **Feature Engineering** — Aggregated 9 raw tables into a 16-feature customer-level profile; defined churn as 180-day purchase inactivity
- **Customer Segmentation** — K-Means clustering (K=4) identifying Champions, Loyal, At-Risk, and Lost segments with PCA visualization
- **Churn Prediction** — XGBoost model (AUC: *TBD*) with SMOTE for class imbalance; compared against Logistic Regression and Random Forest baselines
- **Model Interpretability** — SHAP analysis revealing the exact recency threshold where churn risk spikes and per-customer churn explanations
- **Business Impact** — Quantified revenue at risk and estimated campaign ROI for each at-risk segment
- **Power BI Dashboard** — 4-page interactive dashboard: Executive Overview · Customer Segments · Cohort Retention Heatmap · Churn Risk

---

## Tech Stack
`Python` `SQL (SQLite)` `pandas` `scikit-learn` `XGBoost` `SHAP` `imbalanced-learn` `Power BI`

---

## Dataset
[Olist Brazilian E-Commerce Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — 9 relational tables, ~100K orders, 2016–2018

---

*Full business report and findings in `business_report.md`*
