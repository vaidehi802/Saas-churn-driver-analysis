-- ============================================================================
-- RavenStack Churn & Revenue Analytics - Full MySQL Setup
-- Run this top-to-bottom in MySQL Workbench, in your subscription_revenue
-- schema (or create a new one, e.g. CREATE SCHEMA ravenstack; USE ravenstack;)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: CREATE TABLES
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS churn_events;
DROP TABLE IF EXISTS support_tickets;
DROP TABLE IF EXISTS feature_usage;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    account_id      VARCHAR(20) PRIMARY KEY,
    account_name    VARCHAR(100),
    industry        VARCHAR(50),
    country         VARCHAR(10),
    signup_date     DATE,
    referral_source VARCHAR(30),
    plan_tier       VARCHAR(30),
    seats           INT,
    is_trial        TINYINT,
    churn_flag      TINYINT
);

CREATE TABLE subscriptions (
    subscription_id   VARCHAR(20) PRIMARY KEY,
    account_id        VARCHAR(20),
    start_date        DATE,
    end_date          DATE NULL,
    plan_tier         VARCHAR(30),
    seats             INT,
    mrr_amount        DECIMAL(10,2),
    arr_amount        DECIMAL(10,2),
    is_trial          TINYINT,
    upgrade_flag      TINYINT,
    downgrade_flag    TINYINT,
    churn_flag        TINYINT,
    billing_frequency VARCHAR(20),
    auto_renew_flag   TINYINT
);

CREATE TABLE feature_usage (
    usage_id            VARCHAR(20) PRIMARY KEY,
    subscription_id      VARCHAR(20),
    usage_date           DATE,
    feature_name         VARCHAR(30),
    usage_count          INT,
    usage_duration_secs  INT,
    error_count          INT,
    is_beta_feature      TINYINT
);

CREATE TABLE support_tickets (
    ticket_id                     VARCHAR(20) PRIMARY KEY,
    account_id                    VARCHAR(20),
    submitted_at                  DATETIME,
    closed_at                     DATETIME,
    resolution_time_hours         DECIMAL(10,2),
    priority                      VARCHAR(20),
    first_response_time_minutes   INT,
    satisfaction_score            INT NULL,
    escalation_flag                TINYINT
);

CREATE TABLE churn_events (
    churn_event_id             VARCHAR(20) PRIMARY KEY,
    account_id                 VARCHAR(20),
    churn_date                 DATE,
    reason_code                VARCHAR(30),
    refund_amount_usd          DECIMAL(10,2),
    preceding_upgrade_flag     TINYINT,
    preceding_downgrade_flag   TINYINT,
    is_reactivation            TINYINT,
    feedback_text              VARCHAR(255)
);

-- ----------------------------------------------------------------------------
-- STEP 2: LOAD DATA
-- Replace the file paths below with wherever you saved the 5 CSVs.
-- Booleans in the CSVs are text ("True"/"False"), so we convert them to
-- 1/0 during the load using SET + a temporary @variable per boolean column.
-- If you get "Loading local data is disabled", run first:
--   SET GLOBAL local_infile = 1;
-- and enable "Allow loading local infile" in Workbench's
-- Edit > Preferences > SQL Editor, then reconnect.
-- ----------------------------------------------------------------------------

LOAD DATA LOCAL INFILE 'C:/path/to/ravenstack_accounts.csv'
INTO TABLE accounts
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(account_id, account_name, industry, country, signup_date, referral_source, plan_tier, seats, @is_trial, @churn_flag)
SET is_trial = IF(@is_trial='True',1,0),
    churn_flag = IF(@churn_flag='True',1,0);

LOAD DATA LOCAL INFILE 'C:/path/to/ravenstack_subscriptions.csv'
INTO TABLE subscriptions
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(subscription_id, account_id, start_date, @end_date, plan_tier, seats, mrr_amount, arr_amount,
 @is_trial, @upgrade_flag, @downgrade_flag, @churn_flag, billing_frequency, @auto_renew_flag)
SET end_date = NULLIF(@end_date,''),
    is_trial = IF(@is_trial='True',1,0),
    upgrade_flag = IF(@upgrade_flag='True',1,0),
    downgrade_flag = IF(@downgrade_flag='True',1,0),
    churn_flag = IF(@churn_flag='True',1,0),
    auto_renew_flag = IF(@auto_renew_flag='True',1,0);

LOAD DATA LOCAL INFILE 'C:/path/to/ravenstack_feature_usage.csv'
INTO TABLE feature_usage
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(usage_id, subscription_id, usage_date, feature_name, usage_count, usage_duration_secs,
 error_count, @is_beta_feature)
SET is_beta_feature = IF(@is_beta_feature='True',1,0);

LOAD DATA LOCAL INFILE 'C:/path/to/ravenstack_support_tickets.csv'
INTO TABLE support_tickets
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(ticket_id, account_id, submitted_at, closed_at, resolution_time_hours, priority,
 first_response_time_minutes, @satisfaction_score, @escalation_flag)
SET satisfaction_score = NULLIF(@satisfaction_score,''),
    escalation_flag = IF(@escalation_flag='True',1,0);

LOAD DATA LOCAL INFILE 'C:/path/to/ravenstack_churn_events.csv'
INTO TABLE churn_events
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(churn_event_id, account_id, churn_date, reason_code, refund_amount_usd,
 @preceding_upgrade_flag, @preceding_downgrade_flag, @is_reactivation, feedback_text)
SET preceding_upgrade_flag = IF(@preceding_upgrade_flag='True',1,0),
    preceding_downgrade_flag = IF(@preceding_downgrade_flag='True',1,0),
    is_reactivation = IF(@is_reactivation='True',1,0);

-- ----------------------------------------------------------------------------
-- STEP 3: ANALYSIS VIEWS
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_revenue_overview;
DROP VIEW IF EXISTS v_churn_reasons;
DROP VIEW IF EXISTS v_churn_precursors;
DROP VIEW IF EXISTS v_planchange_impact;
DROP VIEW IF EXISTS v_support_vs_churn;
DROP VIEW IF EXISTS v_usage_vs_churn;
DROP VIEW IF EXISTS v_referral_performance;
DROP VIEW IF EXISTS v_reactivations;
DROP VIEW IF EXISTS v_cohort_retention;

-- 1. REVENUE OVERVIEW
CREATE VIEW v_revenue_overview AS
SELECT
    SUM(CASE WHEN end_date IS NULL THEN mrr_amount ELSE 0 END) AS current_mrr,
    SUM(CASE WHEN end_date IS NULL THEN arr_amount ELSE 0 END) AS current_arr,
    SUM(CASE WHEN end_date IS NULL THEN 1 ELSE 0 END)          AS active_subscriptions,
    SUM(CASE WHEN end_date IS NOT NULL THEN 1 ELSE 0 END)      AS ended_subscriptions,
    COUNT(*)                                                    AS total_subscriptions
FROM subscriptions;

-- 2. CHURN REASONS
CREATE VIEW v_churn_reasons AS
SELECT
    reason_code,
    COUNT(*)                                            AS churn_count,
    ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2)       AS pct_of_churn,
    ROUND(SUM(refund_amount_usd),2)                     AS total_refunds,
    ROUND(AVG(refund_amount_usd),2)                     AS avg_refund
FROM churn_events
GROUP BY reason_code
ORDER BY churn_count DESC;

-- 3. CHURN PRECURSORS
CREATE VIEW v_churn_precursors AS
SELECT
    CASE
        WHEN preceding_upgrade_flag=1 THEN 'Upgraded within 90 days before churn'
        WHEN preceding_downgrade_flag=1 THEN 'Downgraded within 90 days before churn'
        ELSE 'No plan change before churn'
    END AS precursor,
    COUNT(*)                                         AS churn_count,
    ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2)    AS pct_of_churn,
    ROUND(AVG(refund_amount_usd),2)                  AS avg_refund
FROM churn_events
GROUP BY precursor
ORDER BY churn_count DESC;

-- 4. PLAN CHANGE IMPACT
CREATE VIEW v_planchange_impact AS
SELECT
    CASE
        WHEN upgrade_flag=1 THEN 'Upgraded'
        WHEN downgrade_flag=1 THEN 'Downgraded'
        ELSE 'No Change'
    END AS plan_change_type,
    COUNT(*)                       AS subscription_count,
    ROUND(AVG(mrr_amount),2)       AS avg_mrr,
    ROUND(SUM(mrr_amount),2)       AS total_mrr,
    ROUND(100.0*SUM(churn_flag)/COUNT(*),2) AS churn_rate_pct
FROM subscriptions
GROUP BY plan_change_type
ORDER BY subscription_count DESC;

-- 5. SUPPORT EXPERIENCE VS CHURN
CREATE VIEW v_support_vs_churn AS
SELECT
    a.churn_flag,
    COUNT(DISTINCT t.ticket_id)                        AS ticket_count,
    ROUND(AVG(t.resolution_time_hours),2)              AS avg_resolution_hours,
    ROUND(AVG(t.first_response_time_minutes),2)        AS avg_first_response_min,
    ROUND(AVG(t.satisfaction_score),2)                 AS avg_satisfaction,
    ROUND(100.0*SUM(t.escalation_flag)/COUNT(*),2)     AS escalation_rate_pct
FROM support_tickets t
JOIN accounts a ON t.account_id = a.account_id
GROUP BY a.churn_flag;

-- 6. FEATURE USAGE VS CHURN
CREATE VIEW v_usage_vs_churn AS
SELECT
    a.churn_flag,
    COUNT(*)                                    AS usage_events,
    ROUND(AVG(f.usage_count),2)                 AS avg_usage_count,
    ROUND(AVG(f.usage_duration_secs),2)         AS avg_duration_secs,
    ROUND(AVG(f.error_count),2)                 AS avg_errors,
    ROUND(100.0*SUM(f.is_beta_feature)/COUNT(*),2) AS pct_beta_feature_use
FROM feature_usage f
JOIN subscriptions s ON f.subscription_id = s.subscription_id
JOIN accounts a ON s.account_id = a.account_id
GROUP BY a.churn_flag;

-- 7. REFERRAL CHANNEL PERFORMANCE
CREATE VIEW v_referral_performance AS
SELECT
    a.referral_source,
    COUNT(DISTINCT a.account_id)                         AS accounts,
    ROUND(100.0*SUM(a.churn_flag)/COUNT(*),2)             AS churn_rate_pct,
    ROUND(SUM(CASE WHEN s.end_date IS NULL THEN s.mrr_amount ELSE 0 END),2) AS active_mrr
FROM accounts a
LEFT JOIN subscriptions s ON a.account_id = s.account_id
GROUP BY a.referral_source
ORDER BY active_mrr DESC;

-- 8. REACTIVATIONS
CREATE VIEW v_reactivations AS
SELECT
    CASE WHEN is_reactivation=1 THEN 'Reactivated Customer' ELSE 'First-time Churn' END AS customer_type,
    COUNT(*)                          AS churn_count,
    ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS pct_of_all_churn,
    ROUND(AVG(refund_amount_usd),2)   AS avg_refund
FROM churn_events
GROUP BY customer_type;

-- 9. COHORT RETENTION
CREATE VIEW v_cohort_retention AS
SELECT
    DATE_FORMAT(signup_date, '%Y-%m')                  AS cohort_month,
    COUNT(*)                                           AS cohort_size,
    SUM(churn_flag)                                    AS churned_count,
    ROUND(100.0*SUM(churn_flag)/COUNT(*),2)            AS churn_rate_pct
FROM accounts
GROUP BY cohort_month
ORDER BY cohort_month;
