/*====================================================
  DATABASE & TABLE CREATION
======================================================*/

-- Create Database if not exists and use it
CREATE DATABASE IF NOT EXISTS salary_mgmt
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE salary_mgmt;

-- Create Main Employee Performance Table
CREATE TABLE IF NOT EXISTS employe_performance_dataset (
    ID INT PRIMARY KEY,                       -- Unique Employee ID
    Name VARCHAR(100),                        -- Employee Name
    Age INT,                                  -- Employee Age
    Gender VARCHAR(10),                       -- Gender
    Department VARCHAR(50),                   -- Department
    Salary DECIMAL(10,2),                     -- Salary
    Joining_Date DATE,                        -- Date of Joining
    `Performance Score` DECIMAL(3,2),         -- Performance rating (0-5)
    Experience INT,                           -- Years of Experience
    Status VARCHAR(20),                       -- Employment Status (Active/Inactive)
    Location VARCHAR(100),                     -- Office Location
    Session VARCHAR(20)                        -- Training/Work Session
);

/*====================================================
  BASIC DATA CHECKS
======================================================*/

-- Count total records
SELECT COUNT(*) AS total_rows FROM employe_performance_dataset;

-- Preview first 10 records
SELECT * FROM employe_performance_dataset LIMIT 10;

-- Check table structure
DESCRIBE employe_performance_dataset;

/*====================================================
  FILTERING & SELECTION QUERIES
======================================================*/

-- Select specific columns
SELECT Name, Age, Salary FROM employe_performance_dataset;

-- Employees from Sales department
SELECT * FROM employe_performance_dataset
WHERE Department = 'Sales';

-- Employees with salary > 8000 and active status
SELECT * FROM employe_performance_dataset
WHERE Salary > 8000 AND Status = 'Active';

-- Employees with experience > 5 years and performance >= 4
SELECT *
FROM employe_performance_dataset
WHERE Experience > 5 AND `Performance Score` >= 4;

/*====================================================
  DATA UPDATES & TRANSFORMATIONS
======================================================*/

-- Disable safe updates for modifications
SET SQL_SAFE_UPDATES = 0;

-- Replace 'Inactive' with 'Retired'
UPDATE employe_performance_dataset
SET Status = 'Retired'
WHERE Status = 'Inactive';

-- Add Bonus column safely (only add, no drop to avoid errors)
ALTER TABLE employe_performance_dataset
ADD COLUMN Bonus DECIMAL(10,2);

-- Calculate Bonus as 10% of Salary
UPDATE employe_performance_dataset
SET Bonus = Salary * 0.10;

-- Fill missing Performance Scores in IT department with 5
UPDATE employe_performance_dataset
SET `Performance Score` = 5
WHERE Department = 'IT' AND `Performance Score` IS NULL;

-- Set minimum experience to 2 years
UPDATE employe_performance_dataset
SET Experience = 2
WHERE Experience < 2;

/*====================================================
  SALARY NORMALIZATION
======================================================*/

-- Add normalized salary column
ALTER TABLE employe_performance_dataset
ADD COLUMN Norm_Salary DECIMAL(10,4);

-- Compute min and max salary
SELECT MIN(Salary), MAX(Salary)
INTO @min_salary, @max_salary
FROM employe_performance_dataset;

-- Normalize salary between 0 and 1
UPDATE employe_performance_dataset
SET Norm_Salary = (Salary - @min_salary) / (@max_salary - @min_salary);

-- Check normalized salary sample
SELECT Name, Salary, Norm_Salary
FROM employe_performance_dataset
LIMIT 10;

/*====================================================
  CATEGORIZATION COLUMNS
======================================================*/

-- Add Experience Level column
ALTER TABLE employe_performance_dataset
ADD COLUMN Experience_Level VARCHAR(20);

-- Update Experience Level based on years
UPDATE employe_performance_dataset
SET Experience_Level = CASE
    WHEN Experience < 3 THEN 'Junior'
    WHEN Experience BETWEEN 3 AND 7 THEN 'Mid'
    ELSE 'Senior'
END;

-- Add Age Group column
ALTER TABLE employe_performance_dataset
ADD COLUMN Age_Group VARCHAR(20);

-- Update Age Group based on age
UPDATE employe_performance_dataset
SET Age_Group = CASE
    WHEN Age < 30 THEN 'Young'
    WHEN Age BETWEEN 30 AND 50 THEN 'Middle-aged'
    ELSE 'Senior'
END;

/*====================================================
  ANALYTICAL QUERIES
======================================================*/

-- Average salary per department
SELECT Department, ROUND(AVG(Salary),2) AS Avg_Salary
FROM employe_performance_dataset
GROUP BY Department;

-- Top 10% employees by Salary
WITH ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (ORDER BY Salary DESC) AS rn,
         COUNT(*) OVER () AS total_count
  FROM employe_performance_dataset
)
SELECT *
FROM ranked
WHERE rn <= CEIL(total_count * 0.10)
ORDER BY Salary DESC;

-- Rank employees by Salary within Department
SELECT Department, Name, Salary,
       RANK() OVER (PARTITION BY Department ORDER BY Salary DESC) AS Dept_Rank
FROM employe_performance_dataset;

-- Highest performing department
SELECT Department, AVG(`Performance Score`) AS Avg_Score
FROM employe_performance_dataset
GROUP BY Department
ORDER BY Avg_Score DESC
LIMIT 1;

/*====================================================
  DEPARTMENT BUDGET INTEGRATION
======================================================*/

-- Create Department Budget table
CREATE TABLE IF NOT EXISTS department_budget (
    Department VARCHAR(50) PRIMARY KEY,
    Budget DECIMAL(12,2)
);

-- Insert department budgets
INSERT INTO department_budget (Department, Budget) VALUES
('Sales', 1500000),
('IT', 1200000),
('HR', 800000),
('Finance', 1000000),
('Marketing', 950000);

-- Join employees with department budgets
SELECT e.Name, e.Department, e.Salary, d.Budget
FROM employe_performance_dataset e
INNER JOIN department_budget d
ON e.Department = d.Department;

/*====================================================
  VIEWS, LOGS, TRIGGERS & PROCEDURES
======================================================*/

-- Create view for high performers (Performance Score >= 4.5)
CREATE OR REPLACE VIEW high_performers AS
SELECT Name, Department, Salary, `Performance Score`
FROM employe_performance_dataset
WHERE `Performance Score` >= 4.5;

-- Create salary change log table
CREATE TABLE IF NOT EXISTS salary_log (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    EmployeeID INT,
    Old_Salary DECIMAL(10,2),
    New_Salary DECIMAL(10,2),
    Change_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger to log salary updates
DELIMITER //
CREATE TRIGGER after_salary_update
AFTER UPDATE ON employe_performance_dataset
FOR EACH ROW
BEGIN
    IF OLD.Salary <> NEW.Salary THEN
        INSERT INTO salary_log (EmployeeID, Old_Salary, New_Salary)
        VALUES (OLD.ID, OLD.Salary, NEW.Salary);
    END IF;
END //
DELIMITER ;

-- Stored Procedure to calculate bonus
DELIMITER //
CREATE PROCEDURE CalculateBonus()
BEGIN
    UPDATE employe_performance_dataset
    SET Bonus = Salary * 0.10;
END //
DELIMITER ;

-- Execute Bonus Calculation Procedure
CALL CalculateBonus();

/*====================================================
  VERIFICATION QUERIES
======================================================*/

-- Total number of employees
SELECT COUNT(*) AS total_employees FROM employe_performance_dataset;

-- View top high performers
SELECT * FROM high_performers LIMIT 10;

-- Check salary log updates
SELECT * FROM salary_log ORDER BY Change_Date DESC;
