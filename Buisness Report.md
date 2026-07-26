# E-Commerce Customer Analytics Report
**Olist Platform** | **Pavitra Bhargava** | *July 2026*

---

## Executive Summary

This report summarises findings from a full analysis of Olist's Brazilian e-commerce platform, covering **93,350 customers** and **99,441 orders** placed between September 2016 and October 2018. The platform has a strong fulfillment record (97% of orders delivered successfully) and grew revenue from virtually zero to **R\$1.15M per month** within its first year — but that growth has since plateaued. 

The core problem is retention: **59% of customers are classified as churned**, meaning they have not returned for a purchase in over 180 days. An estimated **R\$5.96M in annual revenue** sits with High-Risk customers who are likely to leave. A targeted retention campaign focused on this group is estimated to recover **R\$595,680 in revenue** at an **ROI of 89%**.

> **Key Takeaway:** Churn on this platform is driven by **delivery experience**, not product satisfaction. Customers who waited longer for delivery — or paid more for shipping relative to their order — are measurably less likely to return, regardless of what they bought. Fixing delivery is the most direct lever the business has.

---

## Key Findings

### Finding 1: Revenue Is Highly Concentrated

The **top 25% of customers** by spending generate **nearly 60% of total platform revenue** — a textbook Pareto pattern. The bottom 50% of customers contribute only 19% of revenue combined. Total platform revenue across the analysis period is **R\$15.42M**, with a median order value of **R\$105.63** per transaction.

This concentration matters because it means that losing a small number of high-value customers has an outsized revenue impact. A broad, one-size-fits-all marketing strategy misses this entirely — it over-invests in low-value customers and under-protects the ones who actually drive the business.

---

### Finding 2: Churn Rate Is 59% — and Most Customers Never Came Back at All

Using a 180-day inactivity threshold, **59% of the customer base is classified as churned**. This isn't surprising given the underlying behaviour: only **3.5% of customers** (roughly 3,345 out of 96,000) ever placed more than one order. For most customers, this platform is a one-time purchase destination, not a recurring shopping habit.

**Breakdown by risk level:**
* **31,588 High-Risk customers** (churn probability 60–80%) hold **R\$5.93M** in historical spend.
* **20,636 Critical-Risk customers** (churn probability >80%) hold **R\$2.33M** in historical spend.
* **Combined:** These two groups represent **R\$8.26M in at-risk revenue** — more than half of the platform's total.

High-Risk customers are the more valuable retention target: their average order value (**R\$184**) is significantly higher than Critical-Risk customers (**R\$113**), and they are not yet fully disengaged — making them easier and cheaper to win back.

---

### Finding 3: Delivery Speed Is the Single Biggest Driver of Churn

The relationship between delivery experience and customer retention is one of the clearest findings in the entire analysis, confirmed at every level:

* Customers who gave **1-star reviews** waited an average of **20.9 days** for delivery.
* Customers who gave **5-star reviews** waited an average of **10.2 days** — roughly half as long.
* Every step up in review score corresponds to a shorter delivery time, with no exceptions in the data.

A machine learning model trained to predict churn confirmed this pattern at the feature level:
1. **Actual vs. promised delivery time** (`avg_delivery_delta`) and **raw delivery speed** (`avg_delivery_days`) are the **top two predictors of churn**, ahead of spending history, product category, and review score.
2. The third most important driver is the **freight-to-order-value ratio** — customers who felt they paid too much for shipping relative to what they bought were measurably more likely to not return, especially on smaller orders.

Review score, while correlated with churn, is mostly a downstream symptom of delivery experience. Once delivery metrics are accounted for, review score adds relatively little additional predictive power. In other words: **a bad delivery causes a bad review, not the other way around.**

---

### Finding 4: Customer Segment Breakdown

The customer base divides into four distinct groups, each requiring a different strategy:

| Segment | Customers | Revenue Share | Avg Spend | Churn Rate |
| :--- | :--- | :--- | :--- | :--- |
| **Active Casual Customers** | 50,640 (54.2%) | 44.1% (R\$6.8M) | ~R\$134 | 29% |
| **Lost Customers** | 37,520 (40.2%) | 32.5% (R\$5.0M) | ~R\$133 | ~100% |
| **High Value – At Risk** | 2,770 (2.6%) | 18.2% (R\$2.8M) | ~R\$1,014 | 58% |
| **Loyal Repeat – At Risk** | 2,770 (3.0%) | 5.2% (R\$0.8M) | ~R\$224 | 56% |

* **High Value At-Risk:** **2.6% of customers hold 18.2% of revenue**, and 58% of them are at risk of leaving. This is where the most immediate revenue protection opportunity lies. Losing even a few hundred of these customers has a more significant revenue impact than losing thousands from any other segment.
* **Lost Customers:** This group — **40% of the base** — represents **R\$5M in revenue** that has already been lost. Low-effort, low-cost win-back attempts are worth trying, but heavy investment here is unlikely to pay off given the near-100% churn rate.

---

## Recommendations

### 1. For Active Casual Customers — Convert the First Purchase Into a Second
This is the volume segment — 50,000+ customers who bought recently and haven't yet churned. The goal is simple: get them to buy again before they drift away.

* Send a **personalised follow-up offer within 30–45 days** of first purchase — this is the window where re-engagement is most likely to work, based on cohort retention data showing Month 1 as the peak return period.
* Offer a **modest discount (10–15%)** tied to a product recommendation relevant to their first order category.
* For customers in **consumable categories** (beauty, health, baby products, pet supplies) — these have higher natural repeat rates, so the offer doesn't need to be as aggressive.

### 2. For High Value At-Risk Customers — Protect Them Before They Leave
This is the most urgent group. These are customers who spent R\$1,000+ on average but haven't returned recently. Losing them costs far more than winning them back.

* **Trigger VIP-level outreach immediately** for any High Value customer who has not purchased in 60 days — don't wait for the 90-day or 180-day threshold.
* Offer **personalised, high-value incentives:** free shipping on next order, early access to new products, dedicated support contact.
* **Do not send generic promotional emails** to this group — the high spend history means they expect and deserve a more personal touch.
* **Do not offer heavy discounts** — they have already demonstrated willingness to spend; discounting trains them to wait for deals.

### 3. For Loyal Repeat At-Risk Customers — Keep the Habit Alive
These are the only customers who have proven they can and will buy more than once. That habit is the rarest thing in this dataset.

* Re-engage with a **loyalty-focused message**, not a discount — e.g., *"You're one of our most valued returning customers."*
* Introduce a **simple points or rewards structure** if budget allows — even a lightweight version strengthens the repeat-purchase habit.
* **Trigger outreach at Day 60 of inactivity**, earlier than other segments, since the cost of losing these customers is disproportionately high relative to their small numbers.

### 4. For Lost Customers — One Attempt, Then Move On
These customers have not purchased in over 180 days. The data shows near-100% churn probability for this group.

* Send a **single win-back email** with a meaningful incentive (25–30% off next purchase).
* If no response within 30 days, **remove from active marketing lists**.
* **Reallocate the budget saved** from deprioritising Lost Customers toward Active Casual and High Value At-Risk campaigns — where ROI is demonstrably better.

---

## Model Performance

The churn prediction model is an **XGBoost classifier** trained on 20 customer-level features covering delivery experience, spending history, product category, and review behaviour.

| Model | AUC-ROC | Recall | Precision |
| :--- | :--- | :--- | :--- |
| **Baseline XGBoost** | 0.812 | 86.5% | 74.0% |
| **Tuned XGBoost** | 0.824 | ~77% | Higher |

* **Baseline Model:** Recommended for **large-scale, low-cost campaigns** (email, automated discount codes) because it catches more churners, even at the cost of some false positives.
* **Tuned Model:** Better suited for **expensive, personalised outreach** (phone calls, premium offers) where false positives have a real financial cost.

*The model was validated using 5-fold cross-validation (AUC: 0.858 ± 0.005), confirming the results are stable and not an artifact of a lucky train/test split.*

---

## Estimated Campaign ROI

Campaign targets the **31,588 High-Risk customers** (churn probability 60–80%):

| Metric | Value |
| :--- | :--- |
| **Customers targeted** | 31,588 |
| **Assumed retention rate** | 10% |
| **Customers retained** | 3,158 |
| **Average order value** | R\$184 |
| **Revenue recovered** | **R\$595,680** |
| **Campaign cost** (R\$10/customer) | R\$315,880 |
| **Net revenue gain** | **R\$279,800** |
| **Campaign ROI** | **89%** |

> **ROI Notes:**
> * The campaign **breaks even at a retention rate of just 5.5%**.
> * The 10% retention rate used here is deliberately conservative — these are predominantly one-time buyers, and a 10% re-engagement rate is realistic for a well-executed email + discount campaign.
> * If outreach quality improves (personalisation, better timing, stronger offer), ROI scales directly with retention rate.

---

*Analysis conducted on the Olist Brazilian E-Commerce public dataset (Kaggle). All revenue figures in Brazilian Reais (R\$). Churn defined as no purchase activity in 180+ days from the dataset reference date of August 2018.*
