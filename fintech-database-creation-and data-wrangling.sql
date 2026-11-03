--PHASE 1: STAGING AND DATA BASE CREATION
-- Step 1: Create Database
CREATE DATABASE FintechDB;
GO

USE FintechDB;
GO

-- CREATE SCHEMA 
CREATE SCHEMA staging;
GO

-- Create Users table
CREATE TABLE Users (
    UserID INT PRIMARY KEY,
    SignupDate DATE NOT NULL,
    Country VARCHAR(50) NOT NULL,
    PlanType VARCHAR(20) NOT NULL,
    AcquisitionChannel VARCHAR(30) NOT NULL
);

-- Create Events table
CREATE TABLE Events (
    EventID INT PRIMARY KEY,
    UserID INT NOT NULL,
    EventType VARCHAR(30) NOT NULL,
    FeatureName VARCHAR(30) NULL,
    EventDate DATE NOT NULL,
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);

-- Create Transactions table
CREATE TABLE Transactions (
    TransactionID INT PRIMARY KEY,
    UserID INT NOT NULL,
    TransactionDate DATE NOT NULL,
    TransactionType VARCHAR(30) NOT NULL,
    Amount DECIMAL(12,2) NULL,
    Status VARCHAR(10) NOT NULL,
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);
GO
--created staging tables with import flat file wizard
--Confirm imported Tables 
USE FintechDB;
GO

SELECT 'staging.users' AS table_name, COUNT(*) AS row_count
FROM staging.fintech_users
UNION ALL

SELECT 'staging.events', COUNT(*) 
FROM staging.fintech_events
UNION ALL

SELECT 'staging.transactions', COUNT(*)
FROM staging.fintech_transactions;





--PHASE 2 : DATA CLEANING 

--UserTable Data Cleaning and Transformation
USE FintechDB;
GO

-- STEP A: See the mess first

-- Count how many users per country
SELECT country, COUNT(*) AS n FROM staging.fintech_users GROUP BY country;

-- Count users per plan type
SELECT '[' + plan_type + ']' AS plan_type, COUNT(*) AS n FROM staging.fintech_users GROUP BY plan_type;


-- STEP B: Clean the data and load it into dbo.Users 

-- Copy rows from dirty staging table into the final Users table
INSERT INTO dbo.Users (UserID, SignupDate, Country, PlanType, AcquisitionChannel)
SELECT
    -- Convert the ID into a real whole number
    CAST(user_id AS INT),
    -- Convert the signup date into a real date
    CAST(signup_date AS DATE),
    -- Fix country spelling/casing; any missing or unknown value becomes 'Unknown'
    CASE UPPER(TRIM(country))
        WHEN 'NIGERIA'      THEN 'Nigeria'
        WHEN 'GHANA'        THEN 'Ghana'
        WHEN 'KENYA'        THEN 'Kenya'
        WHEN 'SOUTH AFRICA' THEN 'South Africa'
        ELSE 'Unknown'
    END,
    -- Remove extra spaces from plan type (e.g. "Free " becomes "Free")
    TRIM(plan_type),
    -- Remove extra spaces from acquisition channel
    TRIM(acquisition_channel)
FROM staging.fintech_users;


-- STEP C: Check the cleaned Users table

-- Total rows in the final Users table 
SELECT COUNT(*) AS total_users FROM dbo.Users;

-- Users per country 
SELECT Country, COUNT(*) AS n FROM dbo.Users GROUP BY Country;

-- Users per plan type
SELECT '[' + PlanType + ']' AS plan_type, COUNT(*) AS n FROM dbo.Users GROUP BY PlanType;



--Event Table Data Cleaning and Transformation
-- STEP A: See the duplicates first

-- Total rows in the staging events table 
SELECT COUNT(*) AS total_rows FROM staging.fintech_events;

-- Count of distinct event IDs 
SELECT COUNT(DISTINCT event_id) AS unique_events FROM staging.fintech_events;

-- Show the event IDs that appear more than once, with how many times
SELECT event_id, COUNT(*) AS times_seen
FROM staging.fintech_events
GROUP BY event_id
HAVING COUNT(*) > 1;


-- STEP B: Remove duplicates, clean, and load into dbo.Events 

-- Copy only the first copy of each event into the final Events table
INSERT INTO dbo.Events (EventID, UserID, EventType, FeatureName, EventDate)
SELECT
    -- Convert the event ID into a whole number
    CAST(event_id AS INT),
    -- Convert the user ID into a whole number
    CAST(user_id AS INT),
    -- Remove extra spaces from the event type
    TRIM(event_type),
    -- Remove extra spaces from the feature name 
    TRIM(feature_name),
    -- Convert the event date text into a real date
    CAST(event_date AS DATE)
FROM (
    -- Number each copy of the same event: 1 for the first copy, 2 for the second, and so on
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_id) AS copy_number
    FROM staging.fintech_events
) AS numbered
-- Keep only the first copy of every event, which drops the duplicates
WHERE copy_number = 1;


-- STEP C: Check the result

-- Total rows in the final Events table 
SELECT COUNT(*) AS total_events FROM dbo.Events;

-- Events per type 
SELECT EventType, COUNT(*) AS n FROM dbo.Events GROUP BY EventType;

-- Confirm no event ID appears twice 
SELECT EventID, COUNT(*) AS times_seen FROM dbo.Events GROUP BY EventID HAVING COUNT(*) > 1;



--Transactions Table Data Cleaning and Transformation
-- STEP A: See the mess first

-- Total rows in the staging transactions table 
SELECT COUNT(*) AS total_rows FROM staging.fintech_transactions;

-- Count rows with a missing amount 
SELECT COUNT(*) AS missing_amounts FROM staging.fintech_transactions WHERE amount IS NULL;

-- Count rows per status
SELECT status, COUNT(*) AS n FROM staging.fintech_transactions GROUP BY status;

-- Count rows per transaction type 
SELECT transaction_type, COUNT(*) AS n FROM staging.fintech_transactions GROUP BY transaction_type;


-- STEP B: Clean the data and load it into dbo.Transactions 

-- Copy rows from the staging table into the final Transactions table
INSERT INTO dbo.Transactions (TransactionID, UserID, TransactionDate, TransactionType, Amount, Status)
SELECT
    -- Convert the transaction ID into a whole number
    CAST(transaction_id AS INT),
    -- Convert the user ID into a whole number
    CAST(user_id AS INT),
    -- Convert the transaction date text into a real date
    CAST(transaction_date AS DATE),
    -- Remove extra spaces from the transaction type
    TRIM(transaction_type),
    -- Convert amount to a decimal number; missing amounts stay NULL
    TRY_CAST(amount AS DECIMAL(12,2)),
    -- Remove extra spaces from the status
    TRIM(status)
FROM staging.fintech_transactions;


-- STEP C: Check the result

-- Total rows in the final Transactions table 
SELECT COUNT(*) AS total_transactions FROM dbo.Transactions;

-- Rows with a missing amount 
SELECT COUNT(*) AS missing_amounts FROM dbo.Transactions WHERE Amount IS NULL;

-- Total value of successful transactions with a known amount
SELECT SUM(Amount) AS total_successful_amount FROM dbo.Transactions WHERE Status = 'Success';





--PHASE 3 :VIEWS AND KPI BUILDING
USE FintechDB;
GO

-- Create  a view with one row per user: funnel dates, activation and churn flags
CREATE OR ALTER VIEW dbo.vw_UserSummary AS
SELECT
    -- Basic user details from the Users table
    u.UserID,
    u.SignupDate,
    -- Cohort month = the first day of the month the user signed up 
    DATEFROMPARTS(YEAR(u.SignupDate), MONTH(u.SignupDate), 1) AS CohortMonth,
    u.Country,
    u.PlanType,
    u.AcquisitionChannel,
    -- Date each funnel stage was reached 
    e.VerifiedDate,
    e.KycDate,
    e.FirstTransactionDate,
    -- Date of the user's most recent app login 
    e.LastLoginDate,
    -- Funnel flags: 1 if the user reached the stage, otherwise 0
    CASE WHEN e.VerifiedDate IS NOT NULL THEN 1 ELSE 0 END AS IsVerified,
    CASE WHEN e.KycDate IS NOT NULL THEN 1 ELSE 0 END AS IsKycCompleted,
    -- Activated = completed a first transaction 
    CASE WHEN e.FirstTransactionDate IS NOT NULL THEN 1 ELSE 0 END AS IsActivated,
    -- Churned = has logged in before, but no login since 1 Oct 2026 
    CASE WHEN e.LastLoginDate IS NOT NULL AND e.LastLoginDate < '2026-10-01' THEN 1 ELSE 0 END AS IsChurned
FROM dbo.Users AS u
-- Join to one summarized row per user built from the Events table
LEFT JOIN (
    SELECT
        UserID,
        -- Earliest date for each funnel stage
        MIN(CASE WHEN EventType = 'email_verified'    THEN EventDate END) AS VerifiedDate,
        MIN(CASE WHEN EventType = 'kyc_completed'     THEN EventDate END) AS KycDate,
        MIN(CASE WHEN EventType = 'first_transaction' THEN EventDate END) AS FirstTransactionDate,
        -- Latest app login date
        MAX(CASE WHEN EventType = 'app_login'         THEN EventDate END) AS LastLoginDate
    FROM dbo.Events
    GROUP BY UserID
) AS e ON e.UserID = u.UserID;
GO

-- Check the view: total users and totals per funnel stage
SELECT
    -- Should be 5000
    COUNT(*)            AS total_users,
    -- Should be 4075
    SUM(IsVerified)     AS verified,
    -- Should be 2985
    SUM(IsKycCompleted) AS kyc_completed,
    -- Should be 2215
    SUM(IsActivated)    AS activated,
    -- Number of churned users 
    SUM(IsChurned)      AS churned
FROM dbo.vw_UserSummary;

-- Look at the first 10 rows to make sure the columns make sense
SELECT TOP 10 * FROM dbo.vw_UserSummary;

--Building KPIs
-- Switch to the FintechDB database
USE FintechDB;
GO

-- FUNNEL VIEW: one row per funnel stage with the number of users who reached it
CREATE OR ALTER VIEW dbo.vw_Funnel AS
-- Stage 1: everyone who signed up
SELECT 1 AS StageOrder, 'Signed up' AS Stage, COUNT(*) AS Users FROM dbo.vw_UserSummary
UNION ALL
-- Stage 2: users who verified their email
SELECT 2, 'Email verified', SUM(IsVerified) FROM dbo.vw_UserSummary
UNION ALL
-- Stage 3: users who completed KYC
SELECT 3, 'KYC completed', SUM(IsKycCompleted) FROM dbo.vw_UserSummary
UNION ALL
-- Stage 4: users who made a first transaction (activated)
SELECT 4, 'First transaction', SUM(IsActivated) FROM dbo.vw_UserSummary;
GO


-- COHORT RETENTION VIEW: for each signup month, the share of users still logging in 0, 1, 2... months later
CREATE OR ALTER VIEW dbo.vw_CohortRetention AS
-- Step 1: list each user with their signup (cohort) month
WITH cohort AS (
    SELECT UserID, CohortMonth FROM dbo.vw_UserSummary
),
-- Step 2: list each user once per calendar month in which they logged in
logins AS (
    SELECT DISTINCT UserID,
           DATEFROMPARTS(YEAR(EventDate), MONTH(EventDate), 1) AS ActivityMonth
    FROM dbo.Events
    WHERE EventType = 'app_login'
),
-- Step 3: count how many users are in each cohort (the denominator)
sizes AS (
    SELECT CohortMonth, COUNT(*) AS CohortSize
    FROM cohort
    GROUP BY CohortMonth
)
-- Step 4: count active users per cohort per month number, and turn it into a rate
SELECT
    c.CohortMonth,
    -- Months since signup: 0 = signup month, 1 = next month, and so on
    DATEDIFF(MONTH, c.CohortMonth, l.ActivityMonth) AS MonthNumber,
    COUNT(DISTINCT l.UserID) AS ActiveUsers,
    s.CohortSize,
    -- Retention rate = active users divided by cohort size
    CAST(COUNT(DISTINCT l.UserID) * 1.0 / s.CohortSize AS DECIMAL(5,4)) AS RetentionRate
FROM cohort AS c
-- Link each user to the months they were active
JOIN logins AS l ON l.UserID = c.UserID
-- Link each cohort to its size
JOIN sizes AS s ON s.CohortMonth = c.CohortMonth
-- Ignore any activity before the signup month
WHERE DATEDIFF(MONTH, c.CohortMonth, l.ActivityMonth) >= 0
GROUP BY c.CohortMonth, DATEDIFF(MONTH, c.CohortMonth, l.ActivityMonth), s.CohortSize;
GO


-- CHECK 1: the funnel 
SELECT * FROM dbo.vw_Funnel ORDER BY StageOrder;

-- CHECK 2: the first cohort's retention over time 
SELECT TOP 12 * FROM dbo.vw_CohortRetention ORDER BY CohortMonth, MonthNumber;



-- Switch to the FintechDB database
USE FintechDB;
GO

-- FEATURE ADOPTION VIEW: for each feature, how many activated users used it and what share that is
CREATE OR ALTER VIEW dbo.vw_FeatureAdoption AS
SELECT
    -- The feature name 
    e.FeatureName,
    -- Number of different users who used this feature at least once
    COUNT(DISTINCT e.UserID) AS UsersWhoUsed,
    -- Total activated users
    a.ActivatedUsers,
    -- Adoption rate = users who used the feature divided by activated users
    CAST(COUNT(DISTINCT e.UserID) * 1.0 / a.ActivatedUsers AS DECIMAL(5,4)) AS AdoptionRate
FROM dbo.Events AS e
-- Attach the single activated-users total to every row
CROSS JOIN (
    SELECT SUM(IsActivated) AS ActivatedUsers FROM dbo.vw_UserSummary
) AS a
-- Only look at feature-usage events that name a feature
WHERE e.EventType = 'feature_used' AND e.FeatureName IS NOT NULL
GROUP BY e.FeatureName, a.ActivatedUsers;
GO

-- CHECK: all features ranked from most to least adopted 
SELECT * FROM dbo.vw_FeatureAdoption ORDER BY AdoptionRate DESC;





