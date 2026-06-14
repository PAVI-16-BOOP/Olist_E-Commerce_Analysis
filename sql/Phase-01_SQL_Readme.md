# Phase 1: SQL Analysis — Product & Customer Intelligence System

This readme covers the SQL  phase of my project. Before touching Python or
any ML model, my goal here was simple: **understand the business through the data first**.
Every query below answers a specific business question I had, and the findings from this
phase directly shape what I'm building in the Python feature engineering and ML phases.

The dataset is the Olist Brazilian E-Commerce dataset — 9 relational tables, ~99,441 orders,
~96,000 unique customers, spanning September 2016 to October 2018.

---

## Section 1: Basic Exploration Queries

**File:** `sql/Basic_Exploration_Queries.sql`

### What problem this section answers
Before any analysis, I needed to know: how big is this dataset, is it clean, and what does
"normal" look like? Skipping this step is how you end up with silently wrong numbers three
steps later, so I made sure to start here.

### What I did

**1.1 — Counting orders, customers, and repeat behavior**
I counted total orders (99,441), total payment records (103,886 — more than orders, because
some orders have multiple payment installments), and unique customers (96,096).

By joining `olist_orders_dataset` to `olist_customers_dataset` and comparing total orders to
distinct `customer_unique_id`, I found that **3,345 customers placed more than one order**.

> **Why this matters:** Out of ~96,000 customers, only ~3,300 are repeat buyers. That's
> roughly a 3.5% repeat purchase rate. This single number set my expectations for everything
> downstream — churn was going to be the dominant story in this dataset, not retention.

**1.2 — Data quality check: null values**
I ran null-checks across the primary key columns of all 9 tables (`customer_unique_id`,
`order_id`, `product_id`, `seller_id`, `review_id`, etc.) and found **zero nulls anywhere in
the key columns.** This was good news — it meant I wouldn't need heavy null-handling logic
for identifiers later, only for behavioral columns like review scores and delivery dates.

**1.3 — Order status breakdown**
```
delivered     96,478
shipped         1,107
canceled          625
unavailable       609
invoiced          314
processing        301
created             5
approved            2
```

> **Finding:** 97% of all orders reached "delivered" status. This is why I filtered every
> customer-level analysis with `WHERE order_status = 'delivered'` — the other 3% are orders
> that never completed and would distort revenue and behavior numbers if included.

**1.4 — Monthly revenue trend**
I joined `olist_order_payments_dataset` to `olist_orders_dataset` and grouped by
`EXTRACT(MONTH...)` and `EXTRACT(YEAR...)` to get a month-by-month revenue trend. This gave
me my first look at the overall business trajectory — useful context before I started
segmenting customers.

**1.5 — Revenue by product category and by state**
By joining `order_items` → `products` → `payments` → `customers`, I ranked product
categories and Brazilian states by revenue. **SP, RJ, and MG (São Paulo, Rio de Janeiro,
Minas Gerais) came out as the top 3 states by revenue** — which makes sense, since these are
Brazil's most populous and economically active states.

**1.6 — Average order value (overall and by category)**
I ran a straightforward `AVG(payment_value)` overall and grouped by category, to understand
typical spend per transaction.

**1.7 — Revenue concentration (the Pareto check)**
This was the most important query in this section for me. Using `NTILE(4) OVER (ORDER BY
total_spend_per_customer DESC)`, I split all customers into 4 equal-sized groups (quartiles)
by how much they've spent, and measured what % of total revenue each quartile contributes.

### Key Findings
- **The top 25% of customers (Quartile 1) generate nearly 60% of total revenue**, despite
  being only a quarter of the customer base.
- The **bottom 50% of customers (Quartiles 3 & 4) contribute only ~19% of revenue combined.**
- This is a textbook **Pareto (80/20) pattern** — a small group of customers
  disproportionately drives the business.

### Why this is useful / My interpretation
This single finding justified my entire segmentation strategy for Phase 3. If revenue were
evenly spread across all customers, segmentation wouldn't matter much — every customer would
be roughly equally important. But because revenue is this concentrated, **how I treat my
top 25% vs my bottom 50% has a massive financial impact.**

### My Business Recommendations
- Build loyalty programs and personalized offers specifically for the top quartile —
  losing even a handful of these customers has an outsized revenue impact.
- Target Quartile 2 customers with campaigns designed to nudge them toward Quartile 1
  behavior (slightly bigger baskets, slightly more frequent purchases).
- For the bottom 50%, focus on increasing average order value through bundling and
  minimum-order-value discounts rather than trying to increase purchase frequency
  (which, as Section 1.1 showed, is rare across the board).

### How this feeds into my next phase
This quartile logic is the conceptual foundation for the **RFM segmentation** I built in
Section 3, and the revenue-per-customer numbers calculated here become a core input feature
(`total_spend` / `monetary`) for my churn prediction model in Phase 3.

---

## Section 2: Funnel & Operational Analysis

**File:** `sql/Funnel_Analysis.sql`

### What problem this section answers
I wanted to answer two questions: **(1) Where do orders get "stuck" in the fulfillment
process?** and **(2) Does the customer's experience (delivery speed, review score) actually
relate to whether they come back?** The second question was the more important one for me —
it's the bridge between "operations" and "customer retention."

### What I did

**2.1 — Order delivery funnel**
I calculated what % of all 99,441 orders fall into each status category.

```
delivered    96,478   (97%)
shipped       1,107   (1.1%)
canceled        625   (0.6%)
unavailable     609   (0.6%)
invoiced        314
processing      301
```

### Key Findings
- 97% of orders are successfully delivered — a strong fulfillment rate.
- Only ~1.2% of orders fail outright (canceled + unavailable combined).
- ~1.1% of orders are still showing as "shipped" — these are either in transit or stuck.

### My Interpretation
The core fulfillment process works well. The opportunities for improvement I see are narrow
but real: reducing cancellations/unavailability through better inventory forecasting, and
investigating whether "shipped" orders that never close out point to a logistics partner
issue.

---

**2.2 — Delivery time analysis**

I computed delivery time as `order_delivered_customer_date - order_purchase_timestamp`,
handling a data quirk where some delivery date fields were empty strings (`''`) rather than
proper NULLs — I had to wrap these with `NULLIF()` before casting to `DATE`.

I calculated the average delivery time and the 25th/50th/75th/90th percentiles.

```
Average delivery time: 12.5 days
p25: 7 days   |   p50 (median): 10 days   |   p75: 16 days   |   p90: 23 days
```

![Distribution of Order Delivery Times]()

### Key Findings
- Half of all orders are delivered within 10 days — reasonable for a large e-commerce
  platform.
- The average (12.5 days) is higher than the median (10 days), which tells me a small number
  of very slow deliveries are pulling the average up — a classic right-skewed distribution
  (visible clearly in the histogram above, with a long tail stretching out to 200+ days).
- The jump from p75 (16 days) to p90 (23 days) shows that roughly 1 in 10 customers
  experience noticeably slower delivery than everyone else.

### My Interpretation
Delivery experience is **not uniform**. Most customers get a reasonable experience, but a
meaningful minority (~10%) wait significantly longer — and I'd expect these to be the same
customers showing up in the 1-star review bucket.

### My Business Recommendations
- Set an internal SLA target, e.g., "deliver 90% of orders within 20 days," and track
  performance against it.
- Investigate whether slow deliveries cluster around specific states, sellers, or product
  categories — if so, that's an actionable fix (e.g., switch logistics partner for that
  region).
- Use delivery time as a feature in my churn model (Phase 3) — this finding is exactly why
  I'm including `avg_delivery_days` and `pct_on_time` as customer-level features.

---

**2.3 — Review score distribution**

```
5 stars: 57,328  (57.8%)
4 stars: 19,142  (19.3%)
3 stars:  8,179  (8.2%)
1 star:  11,424  (11.5%)
2 stars:  3,151  (3.2%)
```

![Distribution of Customer Review Scores](INSERT_IMAGE_PATH_HERE/distribution_of_review_score.png)

### Key Findings
- The vast majority of reviews (77%) are 4 or 5 stars — customers are generally satisfied.
- **1-star reviews (11.5%) outnumber 2-star reviews (3.2%) by more than 3-to-1.** I found
  this interesting — when customers are unhappy, they seem to go straight to the lowest
  possible rating rather than a "moderately bad" 2-star rating. This is a common behavioral
  pattern in review data: dissatisfaction tends to be expressed in extremes.

### My Interpretation
Overall satisfaction looks healthy on the surface, but the 11.5% giving 1-star reviews
represent a meaningful group (over 11,000 reviews) of genuinely bad experiences — likely
tied to the slow-delivery tail I found in 2.2.

### My Business Recommendations
- Treat 1-star reviews as a separate investigation category — I don't want to average them
  away into an overall "4.0 average rating looks fine" narrative.
- Study what the 5-star experiences have in common (likely: fast delivery, accurate product
  description) and try to replicate those conditions more broadly.

---

**2.4 — Does review score predict repeat purchases? (Most important query in this section
for me)**

I grouped customers by their average review score (Low: 1–2, Medium: 3, High: 4–5) and
calculated the repeat purchase rate within each group.

```
Medium (3):  5.4% repeat buyers
High (4-5):  2.8% repeat buyers
Low (1-2):   2.4% repeat buyers
```

![Repeat Purchase Rate by Review Group](INSERT_IMAGE_PATH_HERE/repeat_buyers_by_review_group.png)

### Key Findings — and this one genuinely surprised me
- Repeat purchase rates are **low across every group** (2.4% to 5.4%) — confirming the
  ~3.5% overall repeat rate from Section 1.
- **Customers who gave a "medium" (3-star) review actually have the highest repeat rate**,
  not the happiest (4-5 star) customers. The difference between High and Low groups is
  small.

### My Interpretation (with potential reasons)
This was unexpected — my obvious hypothesis going in ("happy customers come back, unhappy
customers don't") isn't strongly supported by this data. A few possible explanations I'd
consider:

- **Marketplace dynamics, not relationship-driven behavior:** Many customers on this
  platform may be buying for a specific one-off need (a single product), not building an
  ongoing relationship with "Olist" as a brand — Olist is a marketplace aggregator, so
  customers may not even strongly associate their experience with "Olist" vs. the individual
  seller.
- **3-star reviewers might just be a different type of customer altogether** — perhaps more
  frequent, pragmatic shoppers who rate moderately by habit regardless of experience, and
  who simply shop online more often in general (hence higher repeat rate independent of this
  specific order's quality).
- Review score might genuinely be a **weak standalone churn predictor** for this dataset —
  but I think it could still be useful in combination with other features (e.g., review
  score interacting with delivery time, which I plan to test with SHAP dependence plots in
  Phase 3).

### My Business Recommendations
- I wouldn't rely on review score alone as a "loyalty signal" — it's necessary but not
  sufficient.
- I'd still target happy (4-5 star) customers with loyalty programs — they're a large,
  stable base even if their repeat rate isn't dramatically higher.
- I'd follow up specifically with 3-star reviewers — they show signs of being engaged,
  frequent shoppers and might convert well with the right nudge.
- **Most importantly:** I want to combine review score with delivery time, order value, and
  category in my ML model rather than treating it in isolation — this is exactly what I'm
  setting up the Phase 2 feature table and SHAP analysis to test.

### How this feeds into my next phase
- `avg_delivery_days`, `pct_on_time`, and `avg_review_score` all become engineered features
  in my customer-level table.
- The "review score alone isn't a strong predictor" finding sets up a genuinely interesting
  SHAP question for Phase 3: does review score matter more *in combination* with other
  features than on its own? That's something I'm looking forward to investigating.

---

## Section 3: RFM Customer Segmentation

**File:** `sql/RFM_Segmentationsql.sql`

### What problem this section answers
Section 1 told me revenue is concentrated (Pareto effect). This section was my attempt at
the next logical question: **who specifically are these high-value customers, and how do I
group ALL customers into segments the business can act on differently?**

### What I did

I built an `rfm_analysis` SQL VIEW using a chain of CTEs:

1. **`rfm_base`** — for each unique customer, I calculated:
   - `last_purchase` (most recent order date)
   - `frequency` (count of distinct delivered orders)
   - `monetary` (total amount spent)

2. **`rfm_days`** — I calculated `recency_days` = (max date in dataset − customer's last
   purchase date), using a `CROSS JOIN` with a single-row `max_date` CTE.

3. **`rfm_scores`** — I scored each customer 1–5 on each dimension:
   - **Recency score:** `NTILE(5) OVER (ORDER BY recency_days DESC)` — customers with the
     *largest* recency_days (least recent) land in group 1; most recent customers get
     group 5.
   - **Frequency score:** This is where I deviated from a generic NTILE approach. Because
     **the vast majority of customers (90,556 out of ~96,000) have placed exactly 1 order**,
     a standard NTILE(5) on frequency would be meaningless — it would just artificially
     split a single value (1) into different scores. So instead, I used a custom rule:
     `frequency >= 3 → 5`, `frequency = 2 → 4`, `frequency = 1 → 1`.
   - **Monetary score:** `NTILE(5) OVER (ORDER BY monetary ASC)` — lowest spenders get
     score 1, highest spenders get score 5.

   > **Why I made this customization:** A textbook RFM implementation assumes a healthy
   > spread of repeat purchases. My dataset doesn't have that — 94% of customers are
   > one-time buyers. I adapted the scoring logic to fit what the data actually looks like
   > rather than blindly applying a textbook formula, and I think this is exactly the kind
   > of judgment call worth explaining in an interview.

4. **`rfm_segmentation`** — I summed the three scores into `rfm_total` and concatenated them
   into an `rfm_segment` code (e.g., "541").

5. **`customer_types`** — I mapped score combinations into 4 business-readable segments:
   - **Champions:** `r_score >= 4 AND m_score >= 4 AND f_score >= 3` (recent, big spenders,
     who've ordered at least twice)
   - **Loyal:** `r_score >= 3 AND m_score >= 3` (reasonably recent, reasonably good spend —
     regardless of how many times they've ordered)
   - **At-Risk:** `r_score <= 2` (haven't purchased in a long time)
   - **Lost/Inactive:** everything else (low recency, low spend, low everything)

### Key Findings

**Customer counts per segment:**
```
Champions:          985    (~1.0%)
Loyal:           33,090    (~34.4%)
At-Risk:         37,344    (~38.9%)
Lost/Inactive:   21,938    (~22.8%)
```

![Number of Customers by Customer Category](INSERT_IMAGE_PATH_HERE/rfm-segmentation.png)

**Revenue share per segment:**
```
Champions:        2.38%   (R$214,093.69)
Loyal:           49.79%   (R$6,681,179.50)
At-Risk:         40.06%   (R$7,120,812.50)
Lost/Inactive:    7.76%   (R$1,406,469.20)
```

![Percentage of Total Revenue by Customer Category](INSERT_IMAGE_PATH_HERE/rf-revenue-by-category.png)

### Key Findings — and the most important interpretation in this whole phase for me
This result looked surprising to me at first — "Champions" (the segment that requires
repeat purchases) make up less than 1% of customers and only 2.4% of revenue, while "Loyal"
(no repeat-purchase requirement) holds **almost half of total revenue.**

Here's what I think is actually going on:
- Because **94% of customers buy only once**, "true loyalty" in the classic repeat-purchase
  sense barely exists on this platform. The 985 Champions are a tiny, almost negligible
  group.
- The "Loyal" segment (33,090 customers, ~50% of revenue) is mostly made up of customers who
  bought **once, but recently and at a decent order value**. They're not "loyal" in the
  behavioral sense — they're just **recent, reasonably valuable, one-time customers**.
- The "At-Risk" segment is *huge* both in customer count (37,344) AND revenue (40%,
  R$7.1M) — these are customers who *also* spent decently, but it's been a while since their
  last purchase.

### My Interpretation
The real story here, as I see it: **this business doesn't have a "keep the loyal customers
happy" problem — it has a "convert good one-time customers into repeat customers" problem.**
Nearly 90% of the customer base (Loyal + At-Risk = 73% of customers, ~90% of revenue)
consists of people who spent real money but aren't coming back.

### My Business Recommendations
- **For "Loyal" (recent, good spenders, mostly one-time):** This is the highest-leverage
  group in my opinion. A well-timed "come back" offer shortly after their first purchase
  (e.g., a discount code valid for 30–60 days) could convert a meaningful % into second-time
  buyers — and given this group is ~50% of revenue, even a small conversion lift would be
  valuable.
- **For "At-Risk" (good past spend, but it's been a while):** These customers already proved
  they're willing to spend significant money. A win-back campaign here has a much better
  ROI than acquiring a brand-new customer, because I already know their spending potential.
- **For "Champions" (985 customers):** Small group, but proven repeat buyers. White-glove
  treatment, referral incentives, and early access to new products — I'd protect this group
  at all costs since repeat buyers are rare on this platform.
- **For "Lost/Inactive":** Lowest priority. A single low-cost win-back attempt, then
  reallocate budget elsewhere.

### How this feeds into my next phase
- The `recency_days`, `frequency`, and `monetary` values I computed here become direct
  input features for my Python customer-feature table.
- The finding that **frequency=1 for 94% of customers** directly shapes how I'll define the
  churn label in Phase 2 — churn can't be about "stopping repeat purchases" for most
  customers, since they never had a second purchase to begin with. Instead, churn needs to
  be framed around "did this customer return within the recency window," which is exactly
  the 180-day threshold approach I'm planning for Phase 2.
- I also want to cross-validate these segment labels (Champions/Loyal/At-Risk/Lost) against
  the unsupervised K-Means clusters in Phase 3 — do the two approaches agree?

---

## Section 4: Cohort Retention Analysis

**File:** `sql/Cohort_Retention_Analysis.sql`

### What problem this section answers
RFM tells me about customers *as of right now*. Cohort analysis answers a different
question for me: **for customers who first purchased in a given month, what % of them ever
came back in the following months — and is this getting better or worse over time?**

### What I did

**Data cleaning decision:** Before building the cohort table, I checked monthly order
volumes and found that **September 2016 and December 2016 have very few orders** (the
platform was just starting), and **September and October 2018 are the last 2 months** in
the dataset (so they can never show meaningful "future" retention — there's no future data
to measure against). I excluded all 4 of these months from the cohort analysis to avoid
misleading results.

> **Why this matters for interviews:** This is a great example of a judgment call I backed
> with evidence rather than an assumption — I *checked* the data first, saw the volume was
> too low / the time window was too short to be meaningful, and only then made the decision
> to exclude. That's the order of operations I want to be known for.

My pipeline then:
1. **`first_purchase_month`** — assigned each customer a cohort based on the month of their
   first delivered order.
2. **`order_months`** — recorded the month of every subsequent order.
3. **`cohort_data`** — calculated `months_since_first_purchase` using integer year/month
   arithmetic: `(year_diff × 12) + month_diff`.
4. **`retention_counts`** / **`cohort_sizes`** / **`retention_rates`** — counted active
   customers per cohort per period, divided by the cohort's initial size, to get a retention
   percentage.

I also separately calculated **revenue per cohort** and **average revenue per customer per
cohort** by joining cohort assignment to total customer spend.

### Visualizations

**Cohort sizes over time:**

![Number of Customers by Cohort Month](INSERT_IMAGE_PATH_HERE/number-of-customers-by-cohorts.png)

> **Finding:** The platform grew steadily from late 2016 through late 2017, peaking around
> November 2017 (~7,300 new customers in that single month — the largest cohort by far),
> then leveled off to a fairly stable ~6,000–7,000 new customers per month through mid-2018.

**Revenue by cohort:**

![Revenue Metrics by Cohort Month](INSERT_IMAGE_PATH_HERE/revenue-metric-by-cohorts.png)

> **Finding:** The November 2017 cohort produced both the highest total revenue AND had the
> highest customer count — consistent with the chart above. What I found interesting is that
> the **average revenue per customer is fairly stable across almost all cohorts** (mostly in
> the R$150–185 range), even as total cohort size varies a lot. This suggests to me that the
> *type* of customer the platform attracts (in terms of spend per person) has stayed fairly
> consistent over time — growth came from acquiring *more* similar customers, not from
> attracting higher-value ones.

**Cohort retention heatmap:**

![Cohort Retention Heatmap](INSERT_IMAGE_PATH_HERE/cohort_retention_heatmap.png)

### Key Findings
- Retention rates across almost all cohorts are **very low — typically in the 10–40% range
  even at Month 1**, and they decay further (though somewhat noisily) over subsequent
  months. This is consistent with everything I found in Sections 1 and 3: most customers
  simply don't come back.
- There's a lot of **noise/volatility** in the heatmap — some cells show high retention
  (e.g., 0.78 for the Jan-2017 cohort at month 12, or 0.62 for the Oct-2016 cohort at months
  19-20) but I think these are likely based on very small surviving customer counts by that
  point, so a single returning customer creates a large % swing. Early cohorts (2016) in
  particular have small initial sizes, making their later-month percentages statistically
  noisy.
- I don't see any cohort showing a clear "this is our best cohort and it's getting
  consistently better" pattern — retention looks more like background noise around a
  generally low baseline, rather than a clear trend.

### My Interpretation
The platform's growth (visible in the cohort-size chart) has been driven almost entirely by
**new customer acquisition**, not by improving retention of existing customers. Average
revenue per customer staying flat across cohorts reinforces this for me — the business
isn't getting better at extracting more value from existing customers over time; it's just
adding more new ones.

### My Business Recommendations
- I'd argue retention is the single biggest growth lever this business isn't using yet.
  Even modest improvements (e.g., raising Month-1 retention from ~20% to ~30%) would compound
  over time in a way that pure acquisition can't.
- Because average revenue per customer is stable across cohorts, I don't think any
  retention-focused campaign needs to be reinvented per cohort — a single well-designed
  "second purchase" campaign could likely be applied platform-wide.
- Given the noise in later-month retention numbers (small sample sizes), I'd focus retention
  measurement on **Month 1 and Month 2** specifically — these have larger sample sizes and
  are more statistically reliable signals.

### How this feeds into my next phase
- This section is my empirical justification for the **180-day churn definition** I'm using
  in Phase 2 — since most "return" behavior (when it happens at all) seems concentrated in
  the first few months, 180 days is a reasonable cutoff that captures most of the meaningful
  retention window without being too short.
- The cohort structure here (`cohort_month`, `months_since_first_purchase`,
  `retention_rate`) will be reused directly in my Power BI dashboard's retention heatmap
  page (Phase 4).

---

## Summary: What I Established in This SQL Phase

| Question | Answer | Feeds Into |
|---|---|---|
| How concentrated is revenue? | Top 25% of customers = ~60% of revenue (Pareto) | Segmentation logic (RFM, K-Means) |
| Is fulfillment healthy? | Yes — 97% delivered successfully | — |
| Does delivery speed vary a lot? | Yes — 10% of orders take 23+ days | `avg_delivery_days`, `pct_on_time` features |
| Does review score drive repeat purchases? | Surprisingly, not strongly on its own | Motivates checking feature *interactions* via SHAP |
| How many customers are repeat buyers? | Only ~3.5% | Defines what "churn" can realistically mean |
| What does RFM segmentation reveal? | "Loyal" + "At-Risk" = ~90% of revenue, both mostly one-time buyers | Core retention strategy + ML feature inputs |
| Is retention improving over time? | No clear trend — growth is acquisition-driven | Justifies 180-day churn window |

**Next phase:** Python feature engineering — building the customer-level feature table using
`recency_days`, `frequency`, `monetary`, `avg_review_score`, `avg_delivery_days`,
`pct_on_time`, and defining the churn label, followed by K-Means segmentation and the
XGBoost churn model with SHAP interpretation.
