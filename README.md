# SaaS Churn Driver Analysis

A SQL + Power BI project investigating what actually drives customer churn at a
fictional B2B SaaS company, using the **RavenStack** synthetic dataset.

Instead of asking "how much revenue did we lose," this project asks a more
useful question: **why do customers actually leave, and which of the usual
suspects (bad support, low engagement, plan downgrades) actually predict it?**

## Dataset credit

This project uses the **RavenStack** synthetic SaaS dataset, created by
**River @ Rivalytics**. Fully synthetic, no PII, MIT-like license — used here
for educational/portfolio purposes with credit to the original author.
Blog: https://rivalytics.medium.com

## The scenario

RavenStack is a stealth-mode SaaS startup selling AI-driven team tools. It was
piloted with coding bootcamp graduates, and every signup, feature use, support
ticket, and churn event was logged. This project analyzes that data to find
what actually drove conversions, support load, and churn before public launch.

## Data

5 tables, ~32,500 rows total:

| Table | Rows | What it tracks |
|---|---|---|
| `accounts` | 500 | One row per customer company — industry, region, referral source, plan tier, churn status |
| `subscriptions` | 5,000 | Billing history — MRR/ARR, plan tier, upgrade/downgrade flags |
| `feature_usage` | 25,000 | Every feature-use event — usage count, duration, errors |
| `support_tickets` | 2,000 | Every support interaction — resolution time, satisfaction, escalation |
| `churn_events` | 600 | Every cancellation — stated reason, refund given, reactivation status |

Raw CSVs are in `/data`.

## Business questions answered

1. **Revenue snapshot** — current MRR/ARR, active vs. ended subscriptions
2. **Why do people churn?** — reason breakdown, refunds given
3. **Does churn follow a plan change?** — upgrade/downgrade as a warning sign
4. **Are downgrades/upgrades costing revenue?** — MRR and churn rate by plan-change type
5. **Does support experience predict churn?** — satisfaction, resolution time, escalation rate compared
6. **Does feature usage predict retention?** — usage patterns compared between churned and retained accounts
7. **Which acquisition channel brings the best customers?** — churn rate and revenue by referral source
8. **Are there "reactivation" customers?** — win-backs, and whether they churn again
9. **Cohort retention by signup month** — churn rate trend across 24 monthly cohorts

## Setup — MySQL

1. Install MySQL Server + MySQL Workbench if you don't already have them
2. Create a schema: `CREATE SCHEMA ravenstack; USE ravenstack;`
3. Open `sql/ravenstack_mysql_setup.sql` in Workbench
4. Edit the 5 `LOAD DATA LOCAL INFILE` file paths near the top of the "STEP 2" section to point at wherever you saved the CSVs in `/data` — use forward slashes even on Windows
5. Enable local file loading (one-time):
   ```sql
   SET GLOBAL local_infile = 1;
   ```
   Also enable it client-side: Database → Manage Connections → Advanced tab → Others box → add `OPT_LOCAL_INFILE=1`, then reconnect.
6. Run the whole script. It creates 5 tables, loads the data, and builds 9 analysis views + 1 KPI summary view.

**Note on line endings:** these CSVs use Windows-style `\r\n` line endings. The
script's `LOAD DATA` statements are already set to `LINES TERMINATED BY '\r\n'`
to handle this correctly — if you regenerate or re-save any CSV with different
line endings, you may need to adjust this.

## Setup — Power BI

1. Open Power BI Desktop
2. Get Data → Excel workbook → select `powerbi/ravenstack_powerbi_data.xlsx`
3. Select all 10 sheets in the Navigator, click Load
4. View → Themes → Browse for themes → select `powerbi/dark_crm_theme.json`
5. Build visuals per the layout below (or design your own)

### Dashboard layout (2 pages)

**Page 1 — Overview:** 5 KPI cards (MRR, ARR, active subscriptions, churn
rate, refunds given), churn-rate-by-cohort line chart, churn-precursors donut,
churn-reasons table, referral-performance bar chart.

**Page 2 — Deep Dive:** 4 revenue cards, plan-change-impact bar chart,
support-vs-churn table, usage-vs-churn table, reactivations donut.

## Key findings

- **Churn reasons are evenly split** — Features (19%), Support (17.3%),
  Budget (17.3%), Unknown (15.8%), Competitor (15.3%), Pricing (15.2%). No
  single dominant cause.
- **72% of churn has no preceding plan change** — most customers who leave
  didn't downgrade first; churn isn't reliably telegraphed by plan behavior.
- **Downgraded subscriptions churn slightly more** (10.77% vs. 9.80% baseline
  for unchanged plans, 8.70% for upgraded).
- **Support quality does not meaningfully predict churn** — average
  satisfaction (3.97 vs. 4.01) and resolution time (35.92 vs. 35.66 hrs) are
  nearly identical between retained and churned accounts.
- **Feature usage does not meaningfully predict churn either** — usage count,
  duration, and error rates are nearly flat across both groups. Churn here
  isn't being driven by disengagement.
- **Referral source matters a lot** — event-sourced accounts churn most
  (35.1%), partner referrals churn least (15.8%). Partner and organic
  channels bring the most revenue.
- **~10% of churn is a repeat event** — customers who'd already churned once,
  came back, and left again.

## Tech stack

- **Python** (pandas) — data validation and Excel workbook export
- **MySQL** — data storage and the 10 analysis views
- **Power BI Desktop** — dashboard visualization

## Related project

An earlier version of this analysis used fully synthetic, generator-script
data instead of a real Kaggle dataset — see [subscription-revenue-leakage](#)
for that version, which focuses on revenue leakage categories (discounts,
failed payments, churn, expirations, downgrades) rather than churn drivers.
