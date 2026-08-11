# Phase 4: Dashboard & Business Quantification
## Olist E-Commerce Customer Intelligence System

This folder covers the final two deliverables of the project:

Business Quantification — translating the churn model's predictions into actual revenue numbers and campaign ROI
Power BI Dashboard — a 4-page interactive dashboard that brings together everything from the SQL phase, Python EDA, segmentation, and churn model into one place any business stakeholder can explore

### Part 1: Business Quantification

File: Business_Quantification.ipynb
Inputs: customer_features_final.csv, xgb_churn_model_calibrated.pkl

What this notebook does

After the churn model assigns every customer a churn probability score, the natural next question is: what does this actually cost the business? This notebook loads the saved model — now a calibrated version (CalibratedClassifierCV wrapping the XGBoost classifier) for more reliable probability estimates — scores all 93,350 customers, and turns those predictions into revenue and ROI numbers.

Risk Tier Breakdown

I divided all customers into 4 risk tiers based on their predicted churn probability:

Risk Tier	Probability Range	Customer Count

Low Risk	0 – 0.30	  19,311

Medium Risk	0.30 – 0.60 	20,263

High Risk	0.60 – 0.80	   25,391

Critical Risk	0.80 – 1.00  	28,385

Over half the customer base (54,907 customers) sits in High or Critical Risk — consistent with the ~59% churn rate found in the SQL phase. Calibration shifted some mass from High Risk into Critical Risk compared to the earlier uncalibrated run, giving a more conservative (and more trustworthy) read on who's truly at the edge of churning.

Revenue at Risk

I focused the campaign on High Risk customers (0.60–0.80) rather than Critical Risk because:

High Risk customers have higher average spend (R$189 vs R$117) — better ROI to retain them
Critical Risk customers are often already fully disengaged — harder and more expensive to win back

#### Key numbers for the High Risk segment:

* Metric	Value
Customers at high churn risk	25,391
Total historical spend	R$4,915,189
Average order value	R$94
Avg orders per customer	1.024 (almost all one-time buyers)
Estimated annual revenue at risk	 R$4,939,722

The 1.024 average orders figure is pulled directly from the data (high_risk["total_orders"].sum()/len(high_risk)), not assumed — making the revenue-at-risk estimate grounded in real numbers.

* Retention Campaign Scenario

  Assumptions:


-Retention rate	10%	Conservative — these are one-time buyers, harder to convert

-Campaign cost per customer	R$10	Email + automated discount voucher

-Avg order value	R$189	Segment average from high_risk

-Expected orders/customer	1.024	Directly from segment data

* Results:

Metric	Value:

-Customers retained	2,539

-Revenue recovered	R$493,972

-Campaign cost	: R$253,910

-Campaign ROI	95%

-For every R$1 spent on outreach, the business gets back R$1.95.The campaign breaks even at approximately a 5.1% retention rate.
The 10% retention rate is an assumption. The real number depends entirely on offer quality and targeting. I used 10% specifically because this platform's customers are predominantly one-time buyers — it's harder to bring someone back when they only bought once.

### Part 2: Power BI Dashboard

#### **📊📈[Live Dashboard →](https://app.powerbi.com/groups/me/reports/a9ce3b40-7516-4ed0-93e9-ebc2a64fc279/dbbded99042636a4b3f4?experience=power-bi)**

The dashboard has 4 pages, each answering a specific business question. A risk_tier slicer and a segment slicer run across pages 2 and 3 for interactive drill-down.

** Page 1 — Executive Summary

Business question: What does the overall business look like — customers, revenue, churn rate, and growth?

![Executive Summary](/dashboards&buisness_quantification/executive_summary.png)

Visuals on this page:

4 KPI cards: Total Customers (93.35K) · Total Revenue (R$15.42M) · Churn Rate (59%) · Median Order Value (R$105.63)
Revenue by Year and Month (line chart)
YearMonth slicer for time-period filtering

What I see in the revenue trend:

Revenue grew from R$0.05M in Oct 2016 to R$1.15M in Oct 2017 — roughly 23x in one year
A small dip in Apr 2017 (R$0.39M after R$0.57M) breaks the trend briefly before recovering
After Oct 2017 the business plateaus in the R$0.97M–R$1.13M range — the rapid-growth phase has ended and the platform is now in a steadier, acquisition-driven cycle
The plateau is itself the argument for retention: pure acquisition is no longer moving the revenue needle the way it once did

Page summary: The business is healthy but plateaued. With 59% churn and a median order of R$105, the revenue opportunity from retention is as large as from new customer acquisition — possibly larger.

** Page 2 — Customer Segments

Business question: Who are our customers, how much do they spend, and where does churn risk sit across segments?

![Customer Segments](/dashboards&buisness_quantification/Customer%20Segment%20Page.png)

Visuals on this page:
-Count of Customers by Segment (bar chart)
-Sum of Total Spend by Segment (pie chart)
-Customer Spend vs Churn Risk (scatter plot) — coloured by risk tier
-Total Spend by Risk Tier (bar chart)
What each visual shows:

Customer count bar chart:

Active Casual Customers are by far the largest group (~51K customers)
Lost Customers are second (~38K) — a huge portion of the customer base is already lost
Loyal Repeat At-Risk and High Value At-Risk are much smaller groups (~3K and ~2K respectively), but carry disproportionate revenue weight

Revenue pie chart:

Active Casual: 44.12% — largest share of total revenue
Lost Customers: 32.47% — a substantial amount of revenue is associated with customers who are already lost, highlighting the scale of the retention opportunity
High Value At-Risk: 18.2% — only a small fraction of customers but nearly a fifth of total revenue; the highest-value segment to retain
Loyal Repeat At-Risk: 5.21% — small in size but valuable because these customers have demonstrated repeat purchasing behaviour

Scatter plot — Spend vs Churn Risk:

Most customers cluster toward the bottom of the chart (lower spend), across different churn probabilities — representing the mass market
High-spend outliers exist at both low and high churn probabilities, showing that spend alone is not sufficient to identify customers at risk
Critical Risk customers are distributed across different spending levels, reinforcing that the churn model is capturing behavioural signals beyond simply how much a customer spends
The clear separation of customers across churn-probability ranges also shows how the calibrated churn score can be used alongside spending to identify customers requiring attention

Risk Tier revenue bar chart:

High Risk holds the largest total revenue at approximately R$4.9M
Medium Risk follows with approximately R$4.0M
Critical Risk accounts for approximately R$3.7M
Low Risk accounts for approximately R$2.9M
The concentration of revenue across the High, Medium, and Critical Risk tiers shows that a significant amount of customer value is exposed to potential churn, supporting targeted retention campaigns rather than relying only on overall customer counts
Page summary:

Active Casual Customers dominate by headcount and revenue share, but the smaller High Value At-Risk segment represents significant revenue leverage. The scatter plot shows that spending alone cannot identify churn risk, while the risk-tier analysis demonstrates that substantial revenue is distributed among customers with elevated churn probabilities. This supports using the calibrated churn model to prioritize retention efforts based on both customer behaviour and financial value.

** Page 3 — Churn Risk Analysis: Who Is About to Leave?

![Churn Analysis](/dashboards&buisness_quantification/Churn%20Risk%20and%20Revenue%20At%20Risk%20Page.png)

Business question: How is churn risk distributed, and how much revenue is at stake in the highest-risk tiers?

Visuals on this page:

-Number of Customers by Churn Probability Score (histogram)
-Count of Customers by Risk Tier (pie chart)
-4 KPI cards: High Risk Revenue · High Risk Customers · Critical Risk Revenue · Critical Risk Customers
-Histogram interpretation guide (text box)

What the histogram shows:
The distribution is relatively balanced at lower probabilities but rises substantially from 0.5 onwards, indicating that a large portion of customers receive relatively high predicted churn probabilities.
Peak bin: 0.7–0.8 (~20.5K customers) — this is the largest probability range, showing that the model identifies a particularly large group of customers with elevated churn risk.
The 0.6–0.7 bin contains ~10.4K customers, followed by ~15.0K in the 0.7–0.8 bin and ~20.5K in the 0.8–0.9 bin, showing a strong concentration toward the higher-risk end of the distribution.
The lowest-probability bins contain fewer customers than the higher-probability bins, with approximately 7.1K customers in the 0.0–0.1 range and 6.4K in the 0.1–0.2 range.
The overall distribution shows that the calibrated model assigns substantially different probabilities across customers rather than concentrating most predictions around 0.5. This provides useful differentiation when prioritising customers for retention actions.
KPI cards:
High Risk: 25.39K customers, representing approximately R$4.92M in total spend — a major retention target
Critical Risk: 28.0K customers, representing approximately R$3.66M in total spend — the highest-probability churn group and an important priority for intervention
Page summary:

The calibrated model clearly differentiates customers across the churn-probability spectrum, with a substantial concentration toward higher predicted churn probabilities. Approximately 53.4K customers fall into the High or Critical Risk tiers, representing around R$8.58M in combined customer spend. This provides a concrete basis for prioritising retention efforts, with the highest-probability customers requiring the most immediate attention.

** Page 4 — Cohort Retention Heatmap

![Cohort Retention Heatmap](/dashboards&buisness_quantification/cohort_rentention_heatmap.png)

Business question: For each cohort (customers who first bought in a given month), what % came back in subsequent months?

Visuals on this page:

Cohort Retention Matrix — rows: cohort month, columns: months since first purchase (Month 1–10+)
Year and Month slicer for filtering by year or month
Footnote explaining what the values represent

How to read it: Each value is a retention percentage. Apr 2017 × Month 1 = 0.60 means 60% of customers who first bought in April 2017 made another purchase within 30 days.

What the data shows:
-Month 1 retention spans 0.23–0.69 across cohorts — a wide range suggesting that the first 30-day experience has been inconsistent across different time periods.

-Aug, Sep, and Oct 2017 cohorts consistently show the highest Month 1 retention (0.69, 0.68, and 0.69). These months precede the platform's revenue peak, suggesting that the stronger operating conditions during this period were associated with better early retention.

-Across cohorts, retention drops sharply after Month 1 — most cohorts fall below 0.30 by Month 3 and below 0.25 by Month 6. This confirms that the platform's main challenge is not simply acquiring customers, but converting first-time buyers into repeat customers.

-Oct 2016 has sparse and noisy data — as one of the earliest cohorts, it contains relatively few customers, so isolated values such as 0.31 at Month 6 and Month 9 should not be over-interpreted.

-Nov 2017 falls to just 0.05 by Month 9, representing the weakest sustained late-period retention in the table. This was also the platform's largest cohort (~7,300 customers), suggesting that high acquisition volume did not necessarily translate into long-term customer retention.

Page summary: Retention is consistently weak over the long term. The strongest Month 1 retention reached around 69% in the Aug–Oct 2017 cohorts, but retention declines rapidly thereafter, with most cohorts falling below 30% within three months. The heatmap reinforces the earlier SQL finding that the platform has been driven heavily by acquisition rather than repeat purchasing. This provides the broader business context for the churn analysis: the calibrated model identifies which customers are most likely to leave, while the cohort analysis shows why retention itself is a structural business problem. Together with the revenue-at-risk and retention campaign analysis, the dashboard turns this retention problem into a measurable business opportunity
