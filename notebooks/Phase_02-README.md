# Phase 2: Python Analysis — Feature Engineering, Segmentation & Churn Prediction

This document covers the Python phase of the project — everything that happens after the SQL
exploration. The SQL phase told us *what's true* about the business (low repeat-purchase rate,
revenue concentration, delivery time mattering). This phase turns those findings into a
**customer-level dataset**, then uses that dataset for two things: **unsupervised segmentation**
(who are our customers, in groups a business person can act on) and **supervised churn
prediction** (which customers are about to leave, and why).

Three notebooks make up this phase:
- `Phase_02-Python_part_22-06-2026.ipynb` — data loading, cleaning, EDA, and feature engineering
- `Python_Phase_02_Segmentation_Analysis_KMeans_and_PCA.ipynb` — K-Means clustering + PCA
- `CHURN_MODEL_and_SHAP.ipynb` — churn prediction models + SHAP interpretation

---

## Section 1: Data Loading, Cleaning & Building the Master Table

**File:** `Phase_02-Python_part_22-06-2026.ipynb`

### What problem this section answers
The SQL phase worked directly on the database. In Python, we're starting from 9 separate raw
CSVs (orders, items, customers, products, sellers, reviews, payments, category translations).
Before any feature can be built, all of these need to be merged into **one clean table, at the
right grain** (one row per order), with the data-quality issues from Phase 1 actually fixed
rather than just noted.

### What was done

**1.1 — Loading and filtering to delivered orders**
All 9 raw tables were loaded and parsed for date columns (`order_purchase_timestamp`,
`order_delivered_customer_date`, etc.), using `pd.to_datetime(..., errors='coerce')` so that any
malformed dates become `NaT` instead of crashing the pipeline. Just like in the SQL phase, the
dataset was immediately filtered down to `order_status == 'delivered'` — this is the same 97%
subset identified in SQL Section 1.3, kept consistent across both phases on purpose.

**1.2 — Aggregating payments to one row per order**
The payments table has multiple rows per order (each installment is its own row). These were
grouped by `order_id` and summed, so each order ends up with a single `payment_value`. This
mirrors the SQL phase's payment handling, just done in pandas instead of SQL.

**1.3 — Aggregating order items to one row per order**
Same idea for items — an order can contain multiple products, so `items` was grouped by
`order_id` to produce `num_items`, `item_revenue`, `avg_item_price`, `total_freight`, and a
`category` column (using the *mode* of the categories in that order, so multi-category orders
still get one representative label).

**1.4 — Building the master table**
The delivered orders, aggregated items, aggregated payments, and customer info (`customer_city`,
`customer_state`) were merged together into a single `master` table — one row per delivered
order, with everything needed to compute customer-level features later.

**1.5 — Payment sanity check**
A useful data-quality check: `expected_payment = item_revenue + total_freight` was compared
against the actual `payment_value`. Only **~0.54% of orders** had a meaningful mismatch
(difference > R$1) — confirming the payments and items data agree with each other almost
everywhere, so the merge logic can be trusted.

**1.6 — Handling reviews (multiple reviews per order)**
Some orders had more than one review record. These were sorted by `review_creation_date` and
the **latest** review per order was kept (`.groupby('order_id').agg(review_score=('review_score','last'))`)
— the logic being that if a customer left a follow-up review, that's the more accurate final
sentiment.

**1.7 — Missing value handling (with reasoning, not just imputation)**
Three separate missing-value problems were handled, each with a specific justification rather
than a blanket "fill with median":
- **8 orders missing `order_delivered_customer_date`:** checked their review scores first — 7 of
  the 8 had 5-star reviews, which strongly implies the product *was* actually delivered and this
  is a logging gap, not a real delivery failure. These 8 rows were dropped rather than guessed at.
- **Missing `payment_value`:** imputed as `item_revenue + total_freight`, using the same sanity
  check logic validated in step 1.5.
- **Missing `review_score` (646 orders):** these were **left as missing on purpose**, with a
  `has_review` flag created later, instead of being filled in — because looking at their
  `payment_value` distribution showed these customers actually skew *higher* value than average,
  meaning "didn't leave a review" is itself a real behavioral signal worth preserving, not noise
  to be smoothed over.

**1.8 — Delivery time features**
`delivery_days` (actual delivery time) and `estimated_days` (promised delivery time) were
computed, along with `on_time_delivery` as a binary flag. A handful of orders (43) took over 120
days to deliver — these were deliberately **kept** rather than removed, since tree-based models
handle outliers reasonably well and they represent a real (if rare) logistics failure mode worth
capturing.

### Key Findings
- The delivered-orders filter and payment aggregation logic from SQL Phase 1 translate directly
  into pandas — a good sign that the two phases are analyzing the same underlying reality.
- Missing data in this dataset is rarely "random" — in every case checked (delivery date,
  review score), there was a pattern behind *why* it was missing, and that pattern itself became
  a feature (`has_review`) rather than being thrown away.

### How this feeds into the next phase
This clean, order-level `master` table is the single foundation everything else in Phase 2 is
built from — the EDA in Section 2, the customer-level feature table in Section 3, and (via the
saved `customer_features.csv`) the segmentation and churn models in Sections 4 and 5.

---

## Section 2: Exploratory Data Analysis on Order-Level Data

**File:** `Phase_02-Python_part_22-06-2026.ipynb`

### What problem this section answers
Before jumping to customer-level features, it's worth understanding the **order-level**
patterns first — how spread out are order values, and does delivery speed really connect to
review score the way Phase 1's SQL analysis suggested?

### What was done

**2.1 — Order value distribution**
`payment_value` was plotted as a histogram, capped at the 99th percentile (R$1,052) to keep the
chart readable, plus a separate zoomed-in look at just the top 1% of orders.

### Key Findings
- Most orders sit in the **R$50–R$250** range — the distribution is heavily right-skewed, with a
  long tail of expensive orders.

![Order Value Distribution for Top 99 percentile by order value]()
  
- The top 1% of orders (967 orders) are mostly clustered in the R$1,000–R$2,500 range, with only
  a handful of extreme outliers — a single order over R$13,000, and only 17 orders above R$4,000.
- Within that top 1%, about **76% of customers gave a 4-star or higher review** — high-value
  customers are, on the whole, satisfied ones. But digging into the ones who gave lower scores
  showed that **even the low-review high-value orders generate meaningful total revenue**, so
  they shouldn't be ignored just because they're a minority.

### Business Interpretation
This dataset effectively has two different kinds of customers layered on top of each other:
regular shoppers making everyday purchases, and a small premium group making much larger ones.
Treating them identically in a marketing or retention strategy would under-serve the premium
group and over-invest in reaching casual ones with a VIP-style pitch.

**2.2 — Revisiting review score vs. delivery time (this time visually confirmed)**
The relationship flagged in SQL Section 2.4 was recomputed directly from the cleaned Python
data:

```
1 star: 20.9 avg delivery days
2 star: 16.2 avg delivery days
3 star: 13.8 avg delivery days
4 star: 11.8 avg delivery days
5 star: 10.2 avg delivery days
```

![Average Delivery Time by Review Score](eda_delivery_vs_review.png)

### Key Findings
- There's a clean, monotonic relationship: every step up in review score corresponds to a
  shorter average delivery time. 1-star customers waited **almost twice as long** as 5-star
  customers (20.9 vs 10.2 days).
- This confirms — with a much cleaner, order-level view — the same pattern Phase 1's SQL
  analysis found. Delivery speed is one of the strongest levers on customer satisfaction.

### Business Recommendations
- Treat orders taking longer than ~15 days as an operational priority — this is roughly where
  satisfaction starts dropping noticeably.
- Build a "VIP" or premium tier around the top 1% of order values, since they behave like a
  genuinely different customer type.

### How this feeds into the next phase
The delivery-time-vs-review relationship confirmed here directly motivates engineering
`avg_delivery_delta` and `avg_freight_ratio` as customer-level features — and, as it turns out
in Section 5, these become the single most important predictors in the churn model.

---

## Section 3: Customer-Level Feature Engineering & the Churn Label

**File:** `Phase_02-Python_part_22-06-2026.ipynb`

### What problem this section answers
Every model downstream needs data at the **customer** grain, not the order grain. This section
answers: how do we roll up potentially many orders per customer into one row per customer, and
how do we define "churn" in a way that actually makes sense for this dataset?

### What was done

**3.1 — Order-level features that only make sense before aggregation**
A few features were engineered *before* rolling up to customer level, because they need
order-level context:
- **`freight_ratio`** = shipping cost ÷ payment value — captures whether shipping felt
  expensive relative to what was bought.
- **`delivery_delta`** = actual delivery days − estimated delivery days — positive means late,
  negative means early. This is explicitly *not* about when the customer bought, only about
  delivery quality, which matters for avoiding leakage (more on that below).
- **`gave_low_review`** / **`gave_high_review`** / **`has_review`** — binary flags built from
  `review_score`, since a yes/no signal is often more useful to a model than the raw 1–5 number.

**3.2 — Aggregating to customer level**
`master` was grouped by `customer_unique_id` to build `customer_features` — one row per unique
customer — with aggregates covering:
- **Volume:** `total_orders`, `total_spend`, `avg_order_value`, `max_order_value`,
  `min_order_value`
- **Time:** `first_purchase`, `last_purchase`
- **Experience:** `avg_review_score`, `avg_delivery_days`, `pct_on_time`, `avg_freight_ratio`,
  `avg_delivery_delta`
- **Diversity:** `favorite_category`, `num_categories`
- **Geography:** `state`

**3.3 — Derived features (and a leakage fix worth calling out)**
`recency_days` and `customer_age_days` were calculated relative to a fixed reference date (the
latest purchase date in the whole dataset). The tricky one was `avg_days_between_orders`:

> The first version of this feature used `recency_days` as a stand-in gap for customers with
> only 1 order — but since **94% of customers have exactly one order**, and the churn label is
> itself based on `recency_days`, this quietly leaked the churn answer straight into a feature.
> The fix: `avg_days_between_orders` is only calculated for customers with 2+ orders; everyone
> else gets `NaN`, and a separate binary flag, **`has_repeat_orders`**, marks whether a customer
> ever ordered more than once at all. This is exactly the kind of subtle leakage that's easy to
> introduce by accident and important to catch before trusting any model metrics.

**3.4 — The churn label**
```python
CHURN_DAYS = 180
customer_features['churned'] = (customer_features['recency_days'] > CHURN_DAYS).astype(int)
```
A customer is labeled "churned" if it's been more than 180 days since their last order. This
threshold is the same one justified empirically in the SQL cohort-retention analysis (Phase 1,
Section 4) — most of the "will they come back" signal in this dataset shows up within the first
few months, so 180 days is a reasonable cutoff that isn't too short or too generous.

**3.5 — Additional features added after the first modeling attempt**
A second pass of feature engineering was added later (after the first churn model — see Section
5 — showed only modest performance):
- **`is_consumable_category`** — flags customers whose favorite category is something naturally
  repeat-purchase (beauty, perfumery, baby products, pet supplies, stationery).
- **`is_one_time_category`** — the opposite flag, for categories like furniture, electronics,
  and phones that are inherently one-and-done purchases.
- **`spend_tier`** — a 5-bucket version of `total_spend` (via `pd.qcut`), which lets tree models
  pick up non-linear spending effects more easily than the raw continuous number.

### Key Findings
- **Churn rate came out around 65–68%** using the 180-day rule — consistent with the ~3.5%
  repeat-purchase rate found in SQL Phase 1. Most customers in this dataset simply never had a
  second order to begin with.
- The leakage catch in `avg_days_between_orders` is arguably the most important engineering
  decision in this whole phase — it's the difference between a model that looks unrealistically
  perfect and one that reflects something the business can actually trust.

### How this feeds into the next phase
`customer_features.csv` — the saved output of this section — is the single input file both the
K-Means segmentation (Section 4) and the churn model (Section 5) are built on.

---

## Section 4: Customer Segmentation with K-Means & PCA

**File:** `Python_Phase_02_Segmentation_Analysis_KMeans_and_PCA.ipynb`

### What problem this section answers
The SQL phase already built a rule-based RFM segmentation (Champions / Loyal / At-Risk / Lost).
This section asks the same question from a different angle: **if we let an unsupervised
algorithm find groups on its own, without any hand-written rules, does it discover something
similar — or something new?**

### What was done

**4.1 — Preparing features for clustering**
Clustering was deliberately restricted to the 3 classic RFM dimensions — `recency_days`,
`total_orders` (frequency), and `total_spend` (monetary) — rather than throwing in every
available feature. Using more features tends to produce clusters that are statistically
"tighter" but much harder to explain to a business stakeholder; sticking to RFM keeps the
resulting segments interpretable. Features were scaled with `StandardScaler` so recency (measured
in days, large numbers) doesn't dominate spend (measured in R$, different scale) purely due to
units.

**4.2 — Finding the right number of clusters**
Both the **elbow method** (inertia vs. K) and **silhouette score** were computed for K = 2
through 10.

![Elbow Method and Silhouette Score](kmeans_optimal_k.png)

**K = 4** was chosen — not purely from where the elbow bends, but with an explicit business
reason: this dataset is dominated by one-time buyers with a fairly narrow spending range, so a
handful of clusters is enough to meaningfully separate customer types without over-fragmenting
a population that's naturally quite homogeneous.

**4.3 — Interpreting and naming the clusters**
Each of the 4 clusters was profiled by its median recency, orders, spend, and churn rate, then
manually assigned a business-readable name:

| Cluster | Name | Size | Profile |
|---|---|---|---|
| 0 | Active Casual Customers | 54.2% of customers | Recent (within 127 days), mid-range spend, low churn |
| 1 | Lost Customers | 40.2% of customers | Inactive for a long time, mid-range spend, ~100% churned |
| 2 | High Value – At Risk | 2.6% of customers | Very high spend (~R$1,161 avg), recently went inactive, 58% churn |
| 3 | Loyal Repeat – At Risk | 3.0% of customers | Genuine repeat buyers (avg 2.11 orders), high spend, 56% churn |

**4.4 — Visualizing with PCA**
The 3 RFM dimensions were compressed to 2D with PCA for plotting purposes (capturing ~70.8% of
the variance — good enough to trust the general shape, though some cluster separation that
exists in the full 3D space gets visually compressed away).

![Customer Segments Visualized via PCA](kmeans_clusters_pca.png)

### Key Findings
- **Active Casual Customers (54% of customers) generate 44% of revenue** — the single biggest
  segment, and the biggest growth opportunity, since converting even a small fraction into
  repeat buyers would meaningfully move total revenue.
- **High Value At-Risk customers are only 2.6% of the base but 18.2% of revenue** — this is the
  segment where losing individual customers hurts the most.
- **Lost Customers are 40% of the base but only 32.5% of revenue** — low individual value,
  which is important context for deciding *how much* to spend trying to win them back.
- **Loyal Repeat At-Risk is small (3%) but the only segment with proven repeat behavior** — these
  customers have already shown they're capable of coming back once; keeping that habit alive is
  usually cheaper than creating it from scratch in a new customer.

### Business Interpretation
The unsupervised clustering landed on a very similar story to the SQL phase's RFM segmentation,
just drawn slightly differently — a large "everyday" segment, a small but disproportionately
valuable high-spend segment, a large low-value inactive segment, and a tiny genuinely loyal
segment. That two independent methods (rule-based RFM in SQL, unsupervised K-Means in Python)
converge on the same basic shape is a good sign the underlying pattern is real, not an artifact
of one particular method's assumptions.

### Business Recommendations
- **Active Casual Customers:** primary target for "get the second purchase" campaigns —
  post-purchase discounts, personalized recommendations — since this segment is large enough
  that even a small conversion lift compounds into real revenue.
- **High Value At-Risk:** protect at all costs — VIP-style win-back offers, personal outreach.
  Losing a handful of these customers is felt immediately in the revenue numbers.
- **Lost Customers:** low-cost, low-effort win-back attempt only; don't over-invest here given
  the low per-customer value.
- **Loyal Repeat At-Risk:** proactively re-engage before they fully drop off — loyalty rewards
  and reminders — since this group has already demonstrated a repeat-purchase habit that's
  worth preserving.

### How this feeds into the next phase
The `segment` labels and `customer_features_with_segments.csv` output are used for the Power BI
dashboard (Phase 4). The cluster-level churn rates observed here (29% to 100% depending on
segment) also foreshadow just how strong a predictor recency-related behavior is — which is
exactly what the churn model in Section 5 tests formally.

---

## Section 5: Churn Prediction Modeling

**File:** `CHURN_MODEL_and_SHAP.ipynb`

### What problem this section answers
Segmentation groups customers into buckets; churn prediction gives each customer an individual
probability of leaving, which is what a real retention campaign would actually target (e.g.
"email the top 10,000 highest-risk customers this week").

### What was done

**5.1 — First attempt: RFM-adjacent features only**
Three models — Logistic Regression, Random Forest, and XGBoost — were trained on an initial
feature set (`total_orders`, `total_spend`, `avg_order_value`, `avg_review_score`,
`avg_delivery_days`, `pct_on_time`, `num_categories`, `customer_age_days`,
`has_repeat_orders`, `avg_days_between_orders`).

> **The leakage catch, revisited:** The very first version of this model scored an AUC close to
> **1.0** — a huge red flag, since a real-world churn model should never be that good. Digging in
> confirmed the issue described in Section 3.3: `avg_days_between_orders` had been implicitly
> encoding `recency_days`, which is literally what the churn label is built from. After the fix
> (capping the feature to `NaN` for one-time buyers, adding `has_repeat_orders` instead), scores
> dropped to a much more believable range — a good reminder that suspiciously perfect model
> performance is a bug to investigate, not a result to celebrate.

**5.2 — Expanded feature set with delivery/freight features**
After the leakage fix, model performance was more realistic but still modest (~0.65 AUC). A
second round of features was added — `avg_freight_ratio`, `avg_delivery_delta`,
`gave_low_review`, `gave_high_review`, `has_review`, `is_consumable_category`, `spend_tier` —
based on the EDA finding from Section 2 that delivery experience strongly relates to
satisfaction. This is what pushed the model from "mediocre" to genuinely useful.

**5.3 — Proper validation: 5-fold cross-validation**
Rather than trusting a single train/test split, XGBoost was evaluated with **5-fold stratified
cross-validation** (preserving the churn ratio in every fold):

```
AUC-ROC:  ~0.858 ± 0.005   (CV)
Test AUC: 0.812             (held-out set)
```

### Key Findings
- **Churn on this platform is driven by experience quality, not raw spending patterns.** For
  one-time buyers (94% of the base), recency/frequency/monetary look nearly identical whether
  they eventually returned or not — because they all bought once, around the same amount. What
  actually separates "came back" from "didn't" is what happened *during* that one order: was
  delivery late, was shipping expensive relative to the purchase, did they leave a bad review.
- The train/test AUC gap (~0.86 train vs ~0.81 test) indicates **mild overfitting** — real but
  not alarming, and consistent across folds (low standard deviation), meaning it's a genuine
  small overfit rather than one lucky/unlucky split.
- **Recall (0.865) vs. Precision (0.740):** the model catches 86.5% of actual churners, at the
  cost of some false positives. For a retention use case, that's usually the right trade-off —
  missing a customer who's about to leave is typically more expensive than sending an
  unnecessary discount to someone who would have stayed anyway.

**5.4 — Hyperparameter tuning**
A `RandomizedSearchCV` (500 iterations, 5-fold CV, optimizing ROC-AUC) was run over depth,
learning rate, regularization (`reg_alpha`, `reg_lambda`), subsampling, and `scale_pos_weight`
(used here instead of SMOTE to handle class imbalance directly inside XGBoost).

### Key Findings — model comparison
The tuned model traded recall for precision:

| Version | AUC-ROC | Recall | Precision | Behavior |
|---|---|---|---|---|
| Baseline XGBoost | 0.812 | 0.865 | 0.740 | Catches more churners, more false alarms |
| Tuned XGBoost | ~0.824 | ~0.77 | higher | More conservative, fewer false alarms, misses more churners |

The AUC gain from tuning was small (~1.2 points), while recall dropped by nearly 10 points —
which model to prefer genuinely depends on the business scenario:
- **If retention outreach is cheap** (an email, a small coupon) → the baseline model wins, since
  catching more churners matters more than avoiding a few unnecessary contacts.
- **If retention outreach is expensive** (a call, a large discount, premium membership) → the
  tuned model wins, since false positives now cost real money.

### Business Interpretation
There's no single "correct" model here — the right choice depends on how expensive a retention
action is. This is a useful nuance to lead with, since it shows the modeling decision was made
with the business cost structure in mind, not just chasing the highest AUC number.

### Business Recommendations
- Use the **baseline (higher-recall) model** for low-cost, high-volume retention actions (email
  campaigns, automated discount codes).
- Use the **tuned (higher-precision) model** for higher-cost, personalized retention actions
  (phone calls, premium offers, account manager outreach).
- Track both precision and recall over time as the model is retrained — a shift in either
  signals either changing customer behavior or model drift.

### How this feeds into the next phase
Both the feature importances and the saved model (`xgb_churn_model.pkl`) feed directly into
Section 6's SHAP interpretation — which explains not just *which* customers will churn, but
*why*, at both the population and individual-customer level.

---

## Section 6: SHAP Interpretation — Explaining the Churn Model

**File:** `CHURN_MODEL_and_SHAP.ipynb`

### What problem this section answers
A churn probability score alone isn't very actionable — a business team needs to know **why**
a customer is flagged as high-risk in order to design the right intervention. SHAP
(SHapley Additive exPlanations) breaks each prediction down into how much each feature pushed
the outcome toward or away from "churn."

### What was done

**6.1 — Feature importance (XGBoost gain-based)**

![XGBoost Feature Importance](feature_importance.png)

**6.2 — SHAP summary plots for both the baseline and tuned models**

![SHAP Summary Plot — Baseline Model](shap_summary_baseline.png)
![SHAP Summary Plot — Tuned Model](shap_summary_tuned.png)

**6.3 — Individual customer explanations (waterfall plots)**
Rather than picking extreme outliers, representative customers were selected from the top and
bottom 5% of predicted churn probability, and their individual SHAP waterfall plots were
generated to show exactly which features pushed their prediction up or down.

### Key Findings
- **`avg_delivery_delta`** (actual vs. promised delivery time) and **`avg_delivery_days`**
  (raw delivery speed) are consistently the top 2 drivers of churn risk in both models — directly
  confirming the pattern first spotted in SQL Phase 1 and re-confirmed in Section 2's EDA.
- **`avg_freight_ratio`** (shipping cost relative to order value) is the third major driver —
  customers who feel like they're paying a lot for shipping relative to what they bought are
  measurably more likely to churn, especially on smaller orders.
- **Order value features** (min/max/avg order value) matter, but in combination with delivery
  experience rather than on their own — a customer with weak spending *and* a bad delivery
  experience is much higher risk than either factor alone would suggest.
- **Review score is *not* a top predictor** — which sounds surprising at first, but makes sense
  once you notice that delivery experience already captures most of what a bad review would
  tell you. A slow delivery *causes* a low review most of the time, so once delivery metrics are
  in the model, the review score itself adds relatively little new information. This is exactly
  the "feature interaction" question the SQL phase (Section 2.4) predicted would be worth
  investigating with SHAP — and the answer is: delivery experience is the more fundamental
  signal, and review score is mostly downstream of it.
- **Individual waterfall examples** showed that even a customer with an *excellent* delivery
  experience (delivered 14 days early) can still be predicted as high-risk if their overall
  spending is very low — reinforcing that good logistics alone isn't enough to guarantee a
  second purchase; the model weighs low engagement more heavily than a single good delivery.

### Business Interpretation
The single clearest, most actionable finding across the entire Python phase is this: **delivery
experience is the dominant driver of churn on this platform — more than spending history,
more than review scores, more than product category.** This lines up cleanly with what SQL
Phase 1 found (the 1-star vs. 5-star delivery time gap) and gives a much more precise, feature-
level confirmation of it.

### Business Recommendations
- **Prioritize low-value, one-time buyers for early retention outreach** — the SHAP analysis
  shows low order value is one of the strongest churn contributors, so this group needs the
  earliest intervention, before they even have a chance to leave.
- **Reduce the relative shipping cost on small orders** — free-shipping thresholds or bundling
  can directly address the `avg_freight_ratio` effect.
- **Keep investing in delivery speed and reliability** — it's the single biggest lever the
  business has, and it's operational (fixable), not just something to react to after the fact.
- **Build an early-warning system** for customers who show weak purchasing behavior after their
  first order, since delivery quality alone won't save a low-engagement customer.
- **Don't rely on review score as a standalone loyalty signal** (echoing the same conclusion SQL
  Phase 1 reached) — it's mostly a downstream symptom of delivery experience, not an independent
  driver.

### How this feeds into the next phase
The SHAP-confirmed feature importances (`avg_delivery_delta`, `avg_delivery_days`,
`avg_freight_ratio`) become the headline metrics for the Power BI churn-risk dashboard page
(Phase 4), and the model itself (`xgb_churn_model.pkl`) can be used to score new customers as
they come in.

---

## Summary: What the Python Phase Established

| Question | Answer | Feeds Into |
|---|---|---|
| How do we get from raw tables to one row per customer? | Clean, order-level `master` table → grouped to `customer_features` | Everything downstream |
| Is there a leakage risk in the churn label? | Yes — `avg_days_between_orders` leaked `recency_days` into the model | Fixed with `has_repeat_orders` flag; critical modeling lesson |
| What does an unsupervised view of customers look like? | 4 K-Means segments, closely matching the SQL RFM segments | Power BI dashboard, cross-validates SQL segmentation |
| How well can churn be predicted? | ~0.81–0.86 AUC depending on model/validation | Retention targeting |
| What actually drives churn? | Delivery speed & reliability, then freight cost, then spend — *not* review score alone | Business recommendations, SHAP dashboard |
| Baseline vs. tuned model — which is "best"? | Depends on retention-action cost (recall vs. precision trade-off) | Deployment decision, not purely a modeling one |

**Next phase:** Power BI dashboard build, consolidating the RFM segments, K-Means segments,
churn scores, and SHAP-driven business recommendations from both phases into a single
interactive view for stakeholders.
