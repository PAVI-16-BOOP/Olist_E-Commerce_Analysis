import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import pickle

# ── PAGE CONFIG ──────────────────────────────────────────────
st.set_page_config(
    page_title="Olist Customer Intelligence",
    page_icon="🛍️",
    layout="wide"
)

# ── LOAD DATA & MODEL ─────────────────────────────────────────
@st.cache_data
def load_data():
    try:
        return pd.read_csv("data/deployment_df.csv")
    except Exception as e:
        st.error(f"Error loading dataset: {e}")
        st.stop()

@st.cache_resource
def load_model():
    try:
        with open("model/xgb_churn_model_calibrated.pkl", "rb") as f:
            return pickle.load(f)
    except Exception as e:
        st.error(f"Error loading model: {e}")
        st.stop()

df = load_data()
model = load_model()

# ── PASTE YOUR EXACT FEATURE_COLS HERE ───────────────────────
# Replace this list with the output you copied from your notebook
FEATURE_COLS = [
    'total_orders',
    'total_spend',
    'avg_order_value',
    'max_order_value',
    'min_order_value',
    'customer_age_days',
    'avg_review_score',
    'avg_delivery_days',
    'pct_on_time',
    'num_categories',
    'has_repeat_orders',
    'avg_days_between_orders',
    'avg_freight_ratio',
    'avg_delivery_delta',
    'gave_low_review',
    'gave_high_review',
    'has_review',
    'review_missing',
    'is_consumable_category',
    'spend_tier'
]

st.markdown("**End-to-end e-commerce analytics** | SQL · Python · XGBoost · SHAP · Power BI")
st.markdown("---")

# ── TABS ─────────────────────────────────────────────────────
tab1, tab2, tab3 = st.tabs([
    "📊 Customer Segments",
    "🔮 Churn Risk Predictor",
    "💰 Campaign ROI Calculator"
])

# ═══════════════════════════════════════════════════════════════
# TAB 1 — CUSTOMER SEGMENTS
# ═══════════════════════════════════════════════════════════════
with tab1:
    st.header("Customer Segmentation — K-Means (K=4)")
    st.markdown("""
    Customers were grouped using unsupervised K-Means clustering on **Recency, Frequency,
    and Monetary (RFM)** features. K=4 was chosen based on elbow + silhouette analysis,
    with each cluster manually labelled based on its behavioral profile.
    """)

    # ── KPI Cards ──
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Customers", f"{len(df):,}")
    col2.metric("Total Revenue", f"R${df['total_spend'].sum():,.0f}")
    col3.metric("Overall Churn Rate", f"{df['churned'].mean()*100:.1f}%")
    col4.metric("Median Order Value", f"R${df['avg_order_value'].median():,.0f}")

    st.markdown("---")

    # ── Segment Summary Table ──
    st.subheader("Segment Profiles")
    seg_summary = df.groupby('segment').agg(
        Customers=('customer_unique_id', 'count'),
        Revenue=('total_spend', 'sum'),
        Avg_Spend=('total_spend', 'mean'),
        Churn_Rate=('churned', 'mean')
    ).round(2).reset_index()
    seg_summary['Revenue_Share_%'] = (seg_summary['Revenue'] /
                                        seg_summary['Revenue'].sum() * 100).round(1)
    seg_summary['Churn_Rate'] = (seg_summary['Churn_Rate'] * 100).round(1)
    seg_summary.columns = ['Segment', 'Customers', 'Total Revenue (R$)',
                             'Avg Spend (R$)', 'Churn Rate (%)', 'Revenue Share (%)']
    st.dataframe(seg_summary, use_container_width=True)

    # ── Two Charts Side by Side ──
    col_left, col_right = st.columns(2)

    with col_left:
        fig_bar = px.bar(
            seg_summary.sort_values('Customers', ascending=True),
            x='Customers', y='Segment', orientation='h',
            title='Customer Count by Segment',
            color='Segment',
            color_discrete_sequence=px.colors.qualitative.Set2
        )
        fig_bar.update_layout(showlegend=False)
        st.plotly_chart(fig_bar, use_container_width=True)

    with col_right:
        fig_pie = px.pie(
            seg_summary, values='Total Revenue (R$)', names='Segment',
            title='Revenue Share by Segment',
            color_discrete_sequence=px.colors.qualitative.Set2
        )
        st.plotly_chart(fig_pie, use_container_width=True)

    # ── Scatter Plot ──
    st.subheader("Recency vs Spend (bubble size = churn probability)")
    segment_filter = st.multiselect(
        "Filter segments:",
        options=df['segment'].unique().tolist(),
        default=df['segment'].unique().tolist()
    )
    filtered = df[df['segment'].isin(segment_filter)]
    sample = filtered.sample(min(4000, len(filtered)), random_state=42)

    fig_scatter = px.scatter(
        sample,
        x='recency_days', y='total_spend',
        color='segment', size='churn_probability',
        hover_data=['avg_delivery_days', 'avg_review_score', 'risk_tier'],
        title='Customer Behavior Map',
        labels={
            'recency_days': 'Days Since Last Purchase',
            'total_spend': 'Total Spend (R$)',
            'segment': 'Segment'
        },
        color_discrete_sequence=px.colors.qualitative.Set2
    )
    st.plotly_chart(fig_scatter, use_container_width=True)

# ═══════════════════════════════════════════════════════════════
# TAB 2 — CHURN RISK PREDICTOR
# ═══════════════════════════════════════════════════════════════
with tab2:
    st.header("Individual Churn Risk Predictor")
    st.markdown("""
Enter a customer's behavioral profile below to get their predicted churn probability.
The model is a **calibrated XGBoost classifier** trained on 20 customer-level features.
The output probability has been calibrated using **sigmoid (Platt scaling) calibration**
to make the predicted churn probabilities more reliable. Top drivers: delivery lateness,
freight ratio, and order value.
""")
    st.markdown("---")

    col1, col2, col3 = st.columns(3)

    with col1:
        st.subheader("🛒 Purchase Behaviour")
        total_orders = st.slider("Total Orders Placed", 1, 15, 1)
        total_spend = st.number_input("Total Spend (R$)", 10.0, 15000.0, 150.0, step=10.0)
        avg_order_value = st.number_input("Avg Order Value (R$)", 10.0, 5000.0, 150.0, step=10.0)
        max_order_value = st.number_input("Max Single Order Value (R$)", 10.0, 15000.0, 200.0, step=10.0)
        min_order_value = st.number_input("Min Single Order Value (R$)", 10.0, 5000.0, 100.0, step=10.0)
        customer_age_days = st.slider("Customer Age (days since first order)", 0, 700, 90)
        num_categories = st.slider("Number of Product Categories Purchased", 1, 10, 1)

    with col2:
        st.subheader("🚚 Delivery Experience")
        avg_delivery_days = st.slider("Avg Delivery Time (days)", 1, 100, 10)
        avg_delivery_delta = st.slider("Delivery Delta (actual − promised days)", -30, 60, -10,
                                        help="Positive = delivered late. Negative = delivered early.Most real customers: -18 to -6.")
        pct_on_time = st.slider("% Orders Delivered On Time", 0.0, 1.0, 0.80, step=0.05)
        avg_freight_ratio = st.slider("Freight Ratio (shipping cost / order value)", 0.0, 1.5, 0.15,
                                       step=0.01,
                                       help="Higher = customer paid more for shipping relative to product")

    with col3:
        st.subheader("⭐ Review & Category")
        avg_review_score = st.slider("Avg Review Score", 1.0, 5.0, 4.0, step=0.5)
        has_review = st.selectbox("Left a Review?", ["Yes", "No"])
        category_type = st.selectbox(
            "Primary Product Category",
            ["One-time (furniture / electronics / phones)",
             "Consumable (beauty / baby / pet / health)"]
        )

    # ── INPUT CONSISTENCY CHECK ───────────────────────────────
with st.expander("⚠️ Input consistency check", expanded=True):
    warnings_list = []

    # Check 1: if delta is negative (early delivery), pct_on_time should be high
    if avg_delivery_delta < -5 and pct_on_time < 0.5:
        warnings_list.append(
            f"**Delivery delta is {avg_delivery_delta} days (early)** but % on-time is "
            f"set to {pct_on_time:.0%}. If orders arrive early, they're by definition on time. "
            f"Consider setting % on-time closer to 1.0."
        )

    # Check 2: if delta is very positive (very late), pct_on_time should be low
    if avg_delivery_delta > 10 and pct_on_time > 0.8:
        warnings_list.append(
            f"**Delivery delta is +{avg_delivery_delta} days (very late)** but % on-time "
            f"is {pct_on_time:.0%}. These two inputs contradict each other. "
            f"Consider lowering % on-time."
        )

    # Check 3: avg delivery days and delta consistency
    if avg_delivery_days > 30 and avg_delivery_delta < 0:
        warnings_list.append(
            f"**Delivery took {avg_delivery_days} days** (very slow) but delta is negative "
            f"(arrived early). This means the promised date was set extremely far in the future. "
            f"Unusual — check if this is intentional."
        )

    # Check 4: min > max order value
    if min_order_value > max_order_value:
        warnings_list.append(
            "**Min order value is greater than max order value.** Please fix this."
        )

    if warnings_list:
        st.markdown("**The following inputs may be inconsistent:**")
        for w in warnings_list:
            st.warning(w)
        st.markdown(
            "_Note: The model will still run with these inputs, but results may not "
            "reflect realistic customer scenarios._"
        )
    else:
        st.success("✅ Inputs look consistent — no contradictions detected.")

    st.markdown("---")

    st.info(
    "📊 **Context from training data:** Most Olist customers had delivery delta between "
    "**−18 and −6 days** (orders arrived early). Avg delivery time was **10 days** (median). "
    "Freight ratio averaged **0.16** (16% of order value). Churn rate was **59%**."
)

    if st.button("🔮 Predict Churn Risk", type="primary", use_container_width=True):
        # Derived values
        gave_low = float(avg_review_score <= 2)
        gave_high = float(avg_review_score >= 4)
        has_rev = float(has_review == "Yes")
        is_consumable = float("Consumable" in category_type)
        has_repeat = float(total_orders > 1)
        avg_days_btw = (
            float(customer_age_days / (total_orders - 1))
            if total_orders > 1 else -1.0
        )
        # spend_tier: bucket into 1-5 based on total_spend quintiles
        # Using approximate thresholds from your data
        if total_spend < 60:
            spend_tier = 1
        elif total_spend < 100:
            spend_tier = 2
        elif total_spend < 155:
            spend_tier = 3
        elif total_spend < 260:
            spend_tier = 4
        else:
            spend_tier = 5

        input_dict = {
            'total_orders': total_orders,
            'total_spend': total_spend,
            'avg_order_value': avg_order_value,
            'max_order_value': max_order_value,
            'min_order_value': min_order_value,
            'customer_age_days': customer_age_days,
            'avg_review_score': avg_review_score,
            'avg_delivery_days': avg_delivery_days,
            'pct_on_time': pct_on_time,
            'num_categories': num_categories,
            'has_repeat_orders': has_repeat,
            'avg_days_between_orders': avg_days_btw,
            'avg_freight_ratio': avg_freight_ratio,
            'avg_delivery_delta': avg_delivery_delta,
            'gave_low_review': gave_low,
            'gave_high_review': gave_high,
            'has_review': has_rev,
            'review_missing': float(has_review == "No"),
            'is_consumable_category': is_consumable,
            'spend_tier': spend_tier
        }

         # Create input dataframe
        input_df = pd.DataFrame([input_dict])

        # Keep only the features used during training, in the correct order
        input_df = input_df[FEATURE_COLS]

        # Predict churn probability
        prob = model.predict_proba(input_df)[0][1]
        
        # ── Result Display ──
        res_col1, res_col2 = st.columns([1, 2])

        with res_col1:
            if prob < 0.3:
                st.success(f"### ✅ Low Risk\n## {prob*100:.1f}%")
            elif prob < 0.6:
                st.warning(f"### ⚠️ Medium Risk\n## {prob*100:.1f}%")
            elif prob < 0.8:
                st.error(f"### 🔴 High Risk\n## {prob*100:.1f}%")
            else:
                st.error(f"### 🚨 Critical Risk\n## {prob*100:.1f}%")

            risk_tier_label = (
                "Low Risk" if prob < 0.3 else
                "Medium Risk" if prob < 0.6 else
                "High Risk" if prob < 0.8 else
                "Critical Risk"
            )
            st.markdown(f"**Risk Tier:** {risk_tier_label}")

        with res_col2:
            fig_gauge = px.pie(
                values=[prob, 1 - prob],
                names=['Churn Risk', 'Retention Probability'],
                hole=0.65,
                color_discrete_sequence=['#e74c3c', '#2ecc71'],
                title=f"Churn Probability: {prob*100:.1f}%"
            )
            fig_gauge.update_traces(textinfo='none')
            fig_gauge.update_layout(height=280, margin=dict(t=40, b=0, l=0, r=0))
            st.plotly_chart(fig_gauge, use_container_width=True)

        # ── SHAP-informed Explanation ──
        st.markdown("### What's driving this prediction?")
        drivers = []
        if avg_delivery_delta > 5:
            drivers.append(f"🚨 **Late delivery** ({avg_delivery_delta:.0f} days after promised) — the #1 churn driver in SHAP analysis")
        if avg_delivery_delta < -3:
            drivers.append(f"✅ **Early delivery** ({abs(avg_delivery_delta):.0f} days before promised) — reduces churn risk")
        if avg_freight_ratio > 0.25:
            drivers.append(f"🚨 **High freight ratio** ({avg_freight_ratio:.2f}) — customer paying a lot for shipping relative to order value")
        if avg_order_value < 80:
            drivers.append("🚨 **Low order value** — low-spend one-time buyers have higher churn risk")
        if avg_review_score <= 2:
            drivers.append("⚠️ **Low review score** — though delivery experience is the more fundamental driver")
        if avg_delivery_days > 20:
            drivers.append(f"🚨 **Slow delivery** ({avg_delivery_days} days) — 1-star customers average 20.9 days in this dataset")
        if total_orders == 1:
            drivers.append("📌 **One-time buyer** — 94% of customers on this platform bought once; re-engagement is the priority")
        if has_repeat == 1.0:
            drivers.append("✅ **Repeat buyer** — only 3.5% of customers return; this is a positive loyalty signal")
        if is_consumable:
            drivers.append("✅ **Consumable category** — naturally higher repeat purchase rate")

        if drivers:
            for d in drivers:
                st.markdown(d)
        else:
            st.markdown("No strong risk signals detected — profile looks like a low-churn customer.")

# ═══════════════════════════════════════════════════════════════
# TAB 3 — ROI CALCULATOR
# ═══════════════════════════════════════════════════════════════
with tab3:
    st.header("Retention Campaign ROI Calculator")
    st.markdown("""
    Adjust campaign parameters to estimate ROI for targeting high-risk customers.
    Numbers are grounded in real segment data from the model — not generic benchmarks.
    """)
    st.markdown("---")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("⚙️ Campaign Parameters")
        risk_threshold = st.slider(
            "Target customers with churn probability above:",
            0.40, 0.90, 0.70, step=0.05,
            help="Customers with calibrated churn probability at or above this threshold are targeted."
        )
        retention_rate = st.slider("Expected retention rate (%)", 3, 30, 10) / 100
        cost_per_customer = st.number_input(
            "Campaign cost per customer (R$)", 1.0, 100.0, 10.0, step=1.0,
            help="R$10 = email + automated discount voucher"
        )

    # Calculate from actual data
    target_df = df[df['churn_probability'] >= risk_threshold]

    if target_df.empty:
        st.warning("No customers satisfy the selected risk threshold.")
        st.stop()


    n_targeted = len(target_df)
    avg_aov = target_df['avg_order_value'].mean()
    avg_ord = target_df['total_orders'].mean()

    n_retained = int(n_targeted * retention_rate)
    revenue_recovered = n_retained * avg_aov * avg_ord
    campaign_cost_total = n_targeted * cost_per_customer
    net_gain = revenue_recovered - campaign_cost_total
    roi = (net_gain / campaign_cost_total * 100) if campaign_cost_total > 0 else 0
    breakeven_rate = (campaign_cost_total / (n_targeted * avg_aov * avg_ord) * 100
                      if n_targeted > 0 else 0)

    with col2:
        st.subheader("📈 Projected Results")
        m1, m2 = st.columns(2)
        m1.metric("Customers Targeted", f"{n_targeted:,}")
        m2.metric("Customers Retained", f"{n_retained:,}")
        m1.metric("Revenue Recovered", f"R${revenue_recovered:,.0f}")
        m2.metric("Campaign Cost", f"R${campaign_cost_total:,.0f}")

        roi_color = "normal" if roi > 0 else "inverse"
        st.metric(
            "Campaign ROI", f"{roi:.0f}%",
            delta=f"Breaks even at {breakeven_rate:.1f}% retention rate"
        )

        if roi > 0:
            st.success(f"For every R$1 spent, the business gets back R${1 + roi/100:.2f}")
        else:
            st.error("Campaign does not break even at these parameters — adjust retention rate or reduce cost")

    st.markdown("---")
    st.subheader("Revenue at Risk by Tier")

    risk_summary = df.groupby('risk_tier').agg(
        Customers=('customer_unique_id', 'count'),
        Revenue=('total_spend', 'sum'),
        Avg_Churn_Prob=('churn_probability', 'mean')
    ).round(2).reset_index()

    col_left, col_right = st.columns(2)
    with col_left:
        fig_risk_bar = px.bar(
            risk_summary.sort_values('Revenue', ascending=False),
            x='risk_tier', y='Revenue',
            color='risk_tier', title='Total Revenue at Risk by Risk Tier',
            labels={'Revenue': 'Revenue (R$)', 'risk_tier': 'Risk Tier'},
            color_discrete_sequence=px.colors.sequential.Reds_r
        )
        st.plotly_chart(fig_risk_bar, use_container_width=True)

    with col_right:
        fig_risk_pie = px.pie(
            risk_summary, values='Customers', names='risk_tier',
            title='Customer Distribution by Risk Tier',
            color_discrete_sequence=px.colors.sequential.Reds_r
        )
        st.plotly_chart(fig_risk_pie, use_container_width=True)

    # Assumptions box
    st.markdown("---")
    with st.expander("📋 Methodology & Assumptions"):
        st.markdown(f"""
        - **Churn definition:** no purchase in 180+ days from the dataset reference date (Aug 2018)
        - **Model:** XGBoost (AUC-ROC: 0.812 on hold-out · 0.858 ± 0.005 on 5-fold CV · Recall: 86.5%)
        - **Model:** XGBoost classifier with sigmoid probability calibration (Platt scaling)
        - **Probability calibration:** Sigmoid calibration was applied to the trained XGBoost model
            to improve the reliability of predicted churn probabilities
        - **Avg order value and orders per customer** are computed directly from the targeted segment in real data
        - **Retention rate** is user-adjustable; 10% was used as a conservative baseline in the original analysis
        - **Campaign cost** of R$10 assumes email + automated discount voucher; higher-cost interventions (calls, premium offers) should use the tuned model (higher precision) instead
        - **Revenue recovered** = customers retained × avg order value × avg orders per customer
        - Dataset: Olist Brazilian E-Commerce (Kaggle) · 93,350 customers · 2016–2018
        """)

# ── FOOTER ───────────────────────────────────────────────────
st.markdown("---")
st.markdown("""
<div style='text-align: center; color: grey; font-size: 0.85em;'>
Built by <strong>Pavitra Bhargava</strong> | NIT Calicut + IIT Madras |
<a href='https://github.com/PAVI-16-BOOP/Olist_E-Commerce_Analysis'>GitHub Repo</a> |
Dataset: <a href='https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce'>Olist on Kaggle</a>
</div>
""", unsafe_allow_html=True)