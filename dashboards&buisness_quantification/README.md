# Phase 4: Dashboard & Business Quantification
## Olist E-Commerce Customer Intelligence System

This folder covers the final two deliverables of the project:

Business Quantification — translating the churn model's predictions into actual revenue numbers and campaign ROI
Power BI Dashboard — a 4-page interactive dashboard that brings together everything from the SQL phase, Python EDA, segmentation, and churn model into one place any business stakeholder can explore
### Part 1: Business Quantification

File: Business_Quantification.ipynb
Inputs: customer_features_final.csv, xgb_churn_model.pkl

What this notebook does

After the churn model assigns every customer a churn probability score, the natural next question is: what does this actually cost the business? This notebook loads the saved model, scores all 93,350 customers, and turns those predictions into revenue and ROI numbers.

Risk Tier Breakdown

I divided all customers into 4 risk tiers based on their predicted churn probability:

Risk Tier	Probability Range	Customer Count
Low Risk	0 – 0.30	14,143
Medium Risk	0.30 – 0.60	26,983
High Risk	0.60 – 0.80	31,588
Critical Risk	0.80 – 1.00	20,636

Over half the customer base (52,224 customers) sits in High or Critical Risk — consistent with the ~59% churn rate found in the SQL phase.

Revenue at Risk

I focused the campaign on High Risk customers (0.60–0.80) rather than Critical Risk because:

High Risk customers have higher average spend (R$188 vs R$113) — better ROI to retain them
Critical Risk customers are often already fully disengaged — harder and more expensive to win back

#### Key numbers for the High Risk segment:

* Metric	Value
Customers at high churn risk	31,588
Total historical spend	R$5,927,427
Average order value	R$184
Avg orders per customer	1.025 (almost all one-time buyers)
Estimated annual revenue at risk	R$5,956,799

The 1.025 average orders figure is pulled directly from the data (high_risk['total_orders'].mean()), not assumed — making the revenue-at-risk estimate grounded in real numbers.

* Retention Campaign Scenario

  Assumptions:


-Retention rate	10%	Conservative — these are one-time buyers, harder to convert

-Campaign cost per customer	R$10	Email + automated discount voucher

-Avg order value	R$184	Segment average from high_risk

-Expected orders/customer	1.025	Directly from segment data

* Results:

Metric	Value:

-Customers retained	3,158

-Revenue recovered	R$595,680

-Campaign cost	R$315,880

-Campaign ROI	89%

-For every R$1 spent on outreach, the business gets back R$1.89. The campaign breaks even at a retention rate of ~5.5%.
the 10% retention rate is an assumption. The real number depends entirely on offer quality and targeting. I used 10% (not the commonly cited 15%) specifically because this platform's customers are predominantly one-time buyers — it's harder to bring someone back when they only bought once.

### Part 2: Power BI Dashboard

#### Link:  https://app.powerbi.com/groups/6dd1d3b8-cdac-49cc-a583-fabf3976f13b/reports/4014130b-a980-410e-b78b-3e885a289194/046b7472e98a95da526b?experience=power-bi

The dashboard has 4 pages, each answering a specific business question. A risk_tier slicer and a segment slicer run across pages 2 and 3 for interactive drill-down.

** Page 1 — Executive Summary

Business question: What does the overall business look like — customers, revenue, churn rate, and growth?

![]()

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

Visuals on this page:

Count of Customers by Segment (bar chart)
Sum of Total Spend by Segment (pie chart)
Customer Spend vs Churn Risk (scatter plot) — coloured by risk tier
Total Spend by Risk Tier (bar chart)

What each visual shows:

Customer count bar chart:

Active Casual Customers are by far the largest group (~50K customers)
Lost Customers are second (~38K) — a huge portion of the base is already gone
Loyal Repeat and High Value At-Risk are tiny in headcount (~2.7K–2.8K each) but carry disproportionate revenue weight

Revenue pie chart:

Active Casual: 44.12% — largest share by volume
Lost Customers: 32.47% — already-lost revenue that should motivate retention investment
High Value At-Risk: 18.2% — only 2.6% of customers but nearly a fifth of all revenue; highest priority to retain
Loyal Repeat At-Risk: 5.21% — small but the only segment with proven repeat behaviour

Scatter plot — Spend vs Churn Risk:

Most customers cluster in the bottom-left (low spend, varied risk) — the mass market
High-spend outliers exist at both low and high churn probability, meaning spend alone isn't enough to identify who to target — you need the churn model
Critical Risk customers (light blue) are spread across all spend levels, confirming the model is picking up behavioural signals beyond just how much someone spent

Risk Tier revenue bar chart:

High Risk holds the most total revenue (~R$5.9M), more than Critical Risk (~R$2.3M) — explaining the campaign focus on High Risk in the quantification notebook

Page summary: Active Casual Customers dominate by headcount, but High Value At-Risk customers are where the revenue leverage is. The scatter plot makes clear that targeting purely by spend would miss many of the model's most important predictions.

** Page 3 — Churn Risk Analysis: Who Is About to Leave?

Business question: How is churn risk distributed, and how much revenue is at stake in the highest-risk tiers?

Visuals on this page:

Number of Customers by Churn Probability Score (histogram)
Count of Customers by Risk Tier (pie chart)
4 KPI cards: High Risk Revenue · High Risk Customers · Critical Risk Revenue · Critical Risk Customers
Histogram interpretation guide (text box)

What the histogram shows:

The distribution rises steadily from left to right — customers are more likely to be in higher-risk bins than lower ones
Peak bin: 0.7–0.8 (16,392K customers) — the model's most confidently predicted at-risk group
There's a dip at 0.1–0.2 (3,845K) vs the 0.0 bin (5,171K), suggesting a clean separation between the genuinely low-risk group and everyone else
The overall shape — low counts at low probabilities, rising sharply from 0.5 onwards — confirms the model is making confident, decisive predictions rather than sitting uncertainly around 0.5 for most customers. This is a healthy sign for a churn model.

KPI cards:

High Risk: 32K customers, R$5.93M — primary retention target
Critical Risk: 21K customers, R$2.33M — secondary target for a low-cost win-back

Page summary: The model has clearly segmented the customer base. With 53K customers in High or Critical Risk and R$8.26M in combined revenue at stake, the financial case for retention action is concrete and quantifiable.

** Page 4 — Cohort Retention Heatmap

Business question: For each cohort (customers who first bought in a given month), what % came back in subsequent months?

Visuals on this page:

Cohort Retention Matrix — rows: cohort month, columns: months since first purchase (Month 1–10+)
Year and Month slicer for filtering by year or month
Footnote explaining what the values represent

How to read it: Each value is a retention percentage. Apr 2017 × Month 1 = 0.60 means 60% of customers who first bought in April 2017 made another purchase within 30 days.

What the data shows:

Month 1 retention spans 0.23–0.69 across cohorts — a wide range suggesting the "first 30 days" experience is inconsistent across time periods
Aug, Sep, Oct 2017 cohorts consistently show the highest Month 1 retention (0.69, 0.68, 0.69) — these months precede the platform's revenue peak (Page 1), suggesting better platform conditions during that period translated into better early retention
Across all cohorts, retention drops sharply after Month 1 — most cohorts are below 0.30 by Month 3 and below 0.25 by Month 6
Oct 2016 has sparse, noisy data — the platform was brand new and the cohort was tiny, so the occasional values that appear (0.31 at Month 6 and Month 9) are based on very few customers and shouldn't be over-interpreted
Nov 2017 drops to just 0.05 by Month 9 — the weakest sustained late-period retention in the table. This was also the platform's largest cohort (~7,300 customers), which may have included many lower-intent buyers attracted by a high-traffic period

Page summary: Retention is universally low — the best the platform ever achieved was around 60–69% Month 1 retention (Aug–Oct 2017), and everything decays quickly after that. The table confirms the same story the SQL phase established: this business has been driven by acquisition, not retention, and that structural pattern is what the entire churn analysis in this project is designed to address.
