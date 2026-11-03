# Fintech User Journey Analysis

## SECTION 1: INTRODUCTION

### Business Objective

Winning a new user costs money, and that money only pays off if the user goes on to transact and keep coming back. This project follows a cohort of 5,000 simulated fintech customers from the day they sign up, through email verification, KYC, and a first transaction, into ongoing use. It measures how many of them become real, retained customers and where the rest slip away, so that the onboarding, retention, and product teams know where to focus.

### Problem Statement

On the surface, the app looks healthy: users and monthly activity grow every month. Underneath, fewer than half of all signups (44.3%) ever complete a transaction, and almost four in ten of the users who did become active have already gone quiet. The product team can see growth, but it cannot see where users are slipping away, who is most likely to leave, or which parts of the product hold their attention, so improvement effort has no clear target.

### Business Questions

- Which channels, plans, and countries bring in the users who actually activate?
- Where on the path from signup to first transaction do users leave?
- How much of each monthly cohort is still active after 1, 3, 6, and 11 months, and who has already gone quiet?
- Which features do people use, and how sticky is the app day to day?
- How much value moves through the app, what drives it, and how often do transactions fail?

---

## SECTION 2: DATA OVERVIEW

The is a synthethic dataset containing 5,000 users who joined between 1 November 2025 and 31 October 2026, 74,023 logged events (73,290 once duplicates are removed), and 20,894 transactions, spread across four countries, three plans, and four acquisition channels.

### Tools Used

- **SQL Server (T-SQL) in SSMS:** Staging, cleaning, constraints, and reporting views.
- **Power BI Desktop and DAX:** Data model, KPI measures, and dashboard visualization.

### Key Data Fields

#### 1. Users (one row per user)

- `user_id`: Unique ID of the user
- `signup_date`: Day the user joined
- `country`: Nigeria, Kenya, Ghana, or South Africa
- `plan_type`: Free, Premium, or Business
- `acquisition_channel`: Referral, Organic, Social Media, or Paid Ads

#### 2. Events (one row per recorded action)

- `event_id`: Unique ID of the event
- `user_id`: The user who triggered it
- `event_type`: signup, email_verified, kyc_completed, first_transaction, app_login, or feature_used
- `feature_name`: Feature touched in a feature_used event (Transfers, Bill Pay, Savings, Virtual Card, Investments)
- `event_date`: Day it happened

#### 3. Transactions (one row per payment)

- `transaction_id`: Unique ID of the transaction
- `user_id`: The user who made it
- `transaction_date`: Day it happened
- `transaction_type`: Transfer, Card Payment, Deposit, Bill Payment, or Withdrawal
- `amount`: Value of the transaction
- `status`: Success or Failed

#### 4. Fields Created in SQL

- `CohortMonth`: The month a user signed up, used to group users into cohorts.
- `IsVerified`, `IsKycCompleted`, `IsActivated`: Binary flags (1 or 0) indicating if the user reached that step.
- `IsChurned`: Binary flag (1 or 0) indicating if the user has logged in before but not since 1 October 2026.
- `MonthNumber`, `RetentionRate`: Months since signup, and the share of the cohort still logging in.
- `AdoptionRate`: Share of activated users who used a feature at least once.

### Data Cleaning and Transformation Pipeline

The data moved through a staged pipeline, with the original copy kept untouched at the start:

1. **Land:** Imported the three CSV files as-is into a staging schema using the SSMS Import Flat File wizard (Untouched copy: 5,000 users, 74,023 events, 20,894 transactions).
2. **Type:** Created typed dbo tables with primary and foreign keys, converting IDs to integers, dates to DATE, and amounts to DECIMAL(12,2) using CAST and TRY_CAST (bad values become NULL instead of breaking the load).
3. **Standardise:** Trimmed stray spaces (e.g., `"Free "` became `"Free"`) and fixed inconsistent casing (e.g., `"nigeria"` to `"Nigeria"`) to ensure one spelling per plan, channel, and country.
4. **Fill the gaps:** Labelled 100 missing countries as `"Unknown"` and left 209 missing transaction amounts as NULL.
5. **Removed duplicates:** Removed repeated event rows using `ROW_NUMBER()` partitioned by `event_id` (733 duplicates removed, leaving 73,290 events).
6. **Shape:** Built `vw_UserSummary` (one row per user with funnel dates, cohort month, activation, and churn flags), plus `vw_Funnel`, `vw_CohortRetention`, and `vw_FeatureAdoption`.
7. **Model:** Added a date table (1 Nov 2025 to 31 Oct 2026), related users and dates to events and transactions (one-to-many, single direction), and wrote the KPI measures in DAX.
8. **Verify:** Checked row counts, funnel counts (5,000, 4,075, 2,985, 2,215), and total successful transaction value in SQL (229,621,977.53) against Power BI (all figures matched).

> **Note:** Churn is flagged when a user has logged in before but has not logged in since 1 October 2026, which represents the final 30 days of data.

---

## SECTION 3: KEY METRICS

| Stage | Metric | Value |
|---|---|---:|
| Acquire | Total users | 5,000 |
| Acquire | Largest market | Nigeria, 48.5% of users |
| Activate | Verified email | 4,075 (81.5%) |
| Activate | Completed KYC | 2,985 (59.7%) |
| Activate | Made a first transaction | 2,215 (44.3%) |
| Retain | Churn rate | 38.1% (845 users) |
| Retain | Month 1 retention | 40% to 50% |
| Retain | Monthly active users | About 100 growing to about 1,400 |
| Monetise | Successful transaction value | ₦229.62M |
| Monetise | Success rate | 96.09% |
| Monetise | Average transaction | ₦11.55K |

Growth is real, with monthly active users multiplying roughly fourteen-fold over the year, but it is driven by volume. Only 44.3% of signups complete a transaction, and the activity that exists is concentrated in one country and one plan.

---

## SECTION 4:PERFORMANC BREAKDOWN


### 1. The Onboarding Path

The path loses about a quarter of its remaining users at every step after verification:

- **Signed up:** 5,000 users
- **Verified email:** 4,075 users (81.5% conversion from previous step; 925 users lost)
- **Completed KYC:** 2,985 users (73.3% conversion from previous step; 1,090 users lost)
- **First transaction:** 2,215 users (74.2% conversion from previous step; 770 users lost)

The KYC step loses the most people in absolute terms, but no single step is catastrophically broken. The low activation rate comes from steady friction along the whole path, so the fix is a smoother onboarding journey and not a patch at one point.

### 2. Acquisition Channels

Referral brings in the users most likely to activate, but the spread between channels is small:

- **Referral:** 48.6% activation rate
- **Organic:** 44.4% activation rate
- **Social Media:** 42.2% activation rate
- **Paid Ads:** 41.6% activation rate

Only about 7 percentage points separate the best channel from the worst. Where a user comes from changes the odds of activation slightly, but it does not explain why more than half of all signups never transact. Channel changes alone will not fix activation.

### 3. Plans and Markets

Plan type is a far stronger signal than channel for both churn and value:

- **Free Plan:** 3,508 users (70.2% share) | 42.3% churn | ₦70M transaction value | ~₦20K value per user
- **Premium Plan:** 1,095 users (21.9% share) | 29.9% churn | ₦71M transaction value | ~₦65K value per user
- **Business Plan:** 397 users (7.9% share) | 29.7% churn | ₦89M transaction value | ~₦224K value per user

Geographic distribution shows Nigeria leading with 2,427 users (48.5%), followed by Kenya (1,021), Ghana (957), and South Africa (495), with 100 users unrecorded.

The plan most users sit on (Free) is the plan that loses them fastest, while the smallest plan (Business) produces the most value. Growth in user base and growth in financial value are therefore not the same thing.

### 4. Retention and Churn

Users peak one month after signup and then fade at a steady pace:

- Month 1 retention ranges from 40.4% (Jan 2026 cohort) to 49.7% (Mar 2026 cohort).
- The Nov 2025 cohort falls from 40.7% in month 1 to 8.4% in month 11.
- Month 0 is lower (about 32% to 39%), representing an onboarding delay rather than real loss.
- A total of 845 users (38.1% of those ever active) have been inactive since 1 October.

After the initial month 1 peak, retention drops by roughly 3 to 4 percentage points each month, pointing to gradual disengagement. Month 1 retention shows no clear trend over time, confirming that cohort quality has remained static.

### 5. Feature Usage

Two features carry the habit, while two are barely discovered (measured by adoption among activated users):

- **Transfers:** 81.8%
- **Bill Pay:** 71.5%
- **Savings:** 55.1%
- **Virtual Card:** 48.9%
- **Investments:** 38.2%

Transfers and Bill Pay bring people back. Virtual Card and Investments reach fewer than half of activated users, suggesting an awareness gap or weaker product-market fit.

### 6. Money Movement

Value grows with the number of active users, driven largely by Transfers and Business plan users:

- **By Transaction Type:** Transfers (₦84M), Card Payments (₦48M), Deposits (₦43M), Bill Payments (₦32M), Withdrawals (₦23M).
- **Monthly Volume:** Monthly value rises from ~₦2M in November 2025 to ~₦39M in October 2026.
- **Success Rate:** 96.09% of all transactions succeed.

Value growth tracks active user growth, meaning revenue increases by adding people rather than increasing individual spending. The 3.91% failure rate (about 1 in 26 transactions) is a steady source of lost trust.

---

## SECTION 5: FINDINGS AND RECOMMENDATIONS
### Funnel and Retention

![Funnel and Retention](images/fintech-user-journey-funnel-and-retention.png)

### Key Findings

1. **More than half of signups never transact:** Only 44.3% (2,215 of 5,000) complete a first transaction.
2. **KYC causes the largest drop-off:** 1,090 verified users (26.7%) stop before completing KYC.
3. **Engagement peaks early:** Retention reaches 40%–50% in month 1 and slides to ~8% by month 11.
4. **Free plan is vulnerable:** Holds 70% of users and churns at 42.3%, compared to ~30% for paid plans.
5. **Acquisition channel has low variance:** Referral leads (48.6%) and Paid Ads trails (41.6%), a spread of only 7 points.
6. **Core habit features:** Transfers (81.8%) and Bill Pay (71.5%) drive engagement; Investments trails (38.2%).
7. **Business users drive key revenue:** 8% of users generate ₦89M (~₦224K per user vs. ~₦20K for Free users).
8. **Value tracks volume:** Total volume scales with active users up to ₦39M/month, with a 96.09% transaction success rate.
9. **Geographic concentration:** Nigeria accounts for nearly half (48.5%) of the user base.

### Recommendations

#### High Priority

- **Simplify the KYC process:** Introduce a shorter form, save progress automatically, and send automated reminders to verified users who haven't completed KYC. Target: Improve Verified-to-KYC conversion from 73.3%.
- **Prompt first transaction immediately:** Implement guided payment flows or small incentives in the days following KYC completion. Target: Improve KYC-to-transaction conversion from 74.2%.
- **Targeted Free-plan re-engagement:** Run re-engagement campaigns for Free users inactive for 30 days, focused on core utility features like Transfers and Bill Pay. Target: Reduce Free plan churn (currently 42.3%).

#### Medium Priority

- **Optimize acquisition channel spend:** Strengthen referral rewards and re-evaluate Paid Ads ROI before scaling acquisition spend. Target: Improve channel-specific activation rates.
- **Feature discovery campaigns:** Cross-promote Virtual Cards and Investments to active users who rely solely on Transfers. Target: Increase feature adoption and long-term retention.
- **Infrastructure diagnostics:** Analyze the 3.9% failure rate by transaction type and plan to resolve technical bottlenecks. Target: Raise transaction success rate above 98%.
- **B2B / High-value retention:** Introduce dedicated support and tailored perks for Business plan subscribers. Target: Maintain low churn and maximize value per user.

#### Long-Term Priority

- **Geographic diversification:** Run market-expansion tests across Kenya, Ghana, and South Africa to balance country risk. Target: Increase market share outside Nigeria.

### Limitations

- **Fictional Data:** Data is synthetic.
- **Currency Formatting:** Naira (₦) is an illustrative display format; multi-currency operations were not modeled.
- **Short Observation Window:** 12 months of cohort data leaves recent cohorts with limited historical tracking.
- **Static Churn Definition:** Churn is strictly defined as no login within the final 30 days (since 1 October 2026).

---

## Conclusion

The platform excels at user acquisition but struggles with activation and long-term retention. Over half of registered users fail to transact, with onboarding drop-offs concentrated at the KYC stage. Additionally, disengagement occurs progressively on the Free plan, which represents the majority of the user base. Conversely, a small segment of Business users generates significant value. Focus should center on reducing onboarding friction, driving conversion to a first transaction, and nurturing high-value tiers.

---

## AUTHOR

**Ogheneruese Edenede - Data Analyst**
