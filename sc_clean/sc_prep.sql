-- Combine databases into one database, copy all tables in gdb056 into gdb041
SET SQL_SAFE_UPDATES = 0;
SHOW PROCESSLIST;

	-- Show tables and columns to copy
USE gdb056;
SHOW TABLES;

DESCRIBE freight_cost;
DESCRIBE gross_price;
DESCRIBE manufacturing_cost;
DESCRIBE post_invoice_deductions;
DESCRIBE pre_invoice_deductions;

	-- Create and insert copies into gdb041

		-- freight_cost
DROP TABLE IF EXISTS gdb041.freight_cost ;
CREATE TABLE gdb041.freight_cost (
    market VARCHAR(255),
    fiscal_year INT,
    freight_pct DECIMAL(15,10),
    other_cost_pct DECIMAL(15, 10))
;
    
INSERT INTO gdb041.freight_cost (
	market, 
    fiscal_year, 
    freight_pct, 
    other_cost_pct)
SELECT 
	market, 
	fiscal_year, 
    freight_pct, 
    other_cost_pct
FROM gdb056.freight_cost
;

SELECT COUNT(*) FROM gdb056.freight_cost;
SELECT COUNT(*) FROM gdb041.freight_cost;

		-- gross_price
DROP TABLE IF EXISTS gdb041.gross_price ;
CREATE TABLE gdb041.gross_price (
    product_code VARCHAR(255),
    fiscal_year INT,
    gross_price DECIMAL(15,10))
;
    
INSERT INTO gdb041.gross_price (
	product_code, 
    fiscal_year, 
    gross_price)
SELECT 
	product_code, 
    fiscal_year, 
    gross_price
FROM gdb056.gross_price
;

SELECT COUNT(*) FROM gdb056.gross_price;
SELECT COUNT(*) FROM gdb041.gross_price;

		-- manufacturing_cost
DROP TABLE IF EXISTS gdb041.manufacturing_cost ;
CREATE TABLE gdb041.manufacturing_cost (
    product_code VARCHAR(255),
    cost_year INT,
    manufacturing_cost DECIMAL(15,10))
;

INSERT INTO gdb041.manufacturing_cost (
	product_code, 
	cost_year, 
    manufacturing_cost)
SELECT 
	product_code, 
	cost_year, 
    manufacturing_cost
FROM gdb056.manufacturing_cost
;

SELECT COUNT(*) FROM gdb056.manufacturing_cost;
SELECT COUNT(*) FROM gdb041.manufacturing_cost;

		-- post_invoice_deductions
DROP TABLE IF EXISTS gdb041.post_invoice_deductions ;
CREATE TABLE gdb041.post_invoice_deductions (
    customer_code VARCHAR(255),
    product_code VARCHAR(255),
    date DATE,
    discounts_pct DECIMAL(15,10),
    other_deductions_pct DECIMAL(15,10))
;

INSERT INTO gdb041.post_invoice_deductions (
	customer_code, 
    product_code, 
    date, 
    discounts_pct, 
    other_deductions_pct)
SELECT 
	customer_code, 
    product_code, 
    date, 
    discounts_pct, 
    other_deductions_pct
FROM gdb056.post_invoice_deductions
;

SELECT COUNT(*) FROM gdb056.post_invoice_deductions;
SELECT COUNT(*) FROM gdb041.post_invoice_deductions;

		-- pre_invoice_deductions
DROP TABLE IF EXISTS gdb041.pre_invoice_deductions ;
CREATE TABLE gdb041.pre_invoice_deductions (
    customer_code VARCHAR(255),
    fiscal_year INT,
    pre_invoice_discount_pct DECIMAL(25,20))
;
    
INSERT INTO gdb041.pre_invoice_deductions (
	customer_code, 
    fiscal_year, 
    pre_invoice_discount_pct)
SELECT
	customer_code, 
    fiscal_year, 
    pre_invoice_discount_pct
FROM gdb056.pre_invoice_deductions
;

SELECT COUNT(*) FROM gdb056.pre_invoice_deductions;
SELECT COUNT(*) FROM gdb041.pre_invoice_deductions;

-- Drop redundant database
DROP DATABASE IF EXISTS gdb056;

-- Drop redundant columns
USE gdb041;

	-- fact_sales_monthly
DESCRIBE fact_sales_monthly;

ALTER TABLE fact_sales_monthly
DROP COLUMN division,
DROP COLUMN category,
DROP COLUMN market,
DROP COLUMN platform,
DROP COLUMN channel
;

SELECT * FROM fact_sales_monthly;

	-- fact_forecast_monthly
DESCRIBE fact_forecast_monthly;

ALTER TABLE fact_forecast_monthly
DROP COLUMN division,
DROP COLUMN category,
DROP COLUMN market,
DROP COLUMN platform,
DROP COLUMN channel
;

SELECT * FROM fact_forecast_monthly;

-- Add fiscal year column, company fiscal year starts in September

	-- fact_sales_monthly  
SELECT * FROM fact_sales_monthly;

SELECT DISTINCT
	date,
	MONTH(date) AS month_number,
    CASE WHEN MONTH(date) >=9 THEN DATE_ADD(date, INTERVAL 4 MONTH) ELSE date END AS fiscal_date,
    CASE WHEN MONTH(date) >=9 THEN YEAR(DATE_ADD(date, INTERVAL 4 MONTH)) ELSE YEAR(date) END AS fiscal_year
FROM fact_sales_monthly
;

ALTER TABLE fact_sales_monthly
ADD COLUMN fiscal_year INT
;
	
UPDATE fact_sales_monthly
SET fiscal_year = CASE WHEN MONTH(date) >=9 THEN YEAR(DATE_ADD(date, INTERVAL 4 MONTH)) ELSE YEAR(date) END
;

SELECT * FROM fact_sales_monthly;

	-- fact_forecast_monthly  
SELECT * FROM fact_forecast_monthly;

SELECT DISTINCT
	date,
	MONTH(date) AS month_number,
    CASE WHEN MONTH(date) >=9 THEN DATE_ADD(date, INTERVAL 4 MONTH) ELSE date END AS fiscal_date,
    CASE WHEN MONTH(date) >=9 THEN YEAR(DATE_ADD(date, INTERVAL 4 MONTH)) ELSE YEAR(date) END AS fiscal_year
FROM fact_forecast_monthly
;

ALTER TABLE fact_forecast_monthly
ADD COLUMN fiscal_year INT
;

UPDATE fact_forecast_monthly
SET fiscal_year = CASE WHEN MONTH(date) >=9 THEN YEAR(DATE_ADD(date, INTERVAL 4 MONTH)) ELSE YEAR(date) END
;

SELECT * FROM fact_forecast_monthly;

-- Add calculated columns: gross_sales, net_invoice_sales, net_sales, cost_of_goods, gross_margin, net_profit

	-- gross_sales
SELECT * FROM fact_sales_monthly;
SELECT * FROM gross_price;

		-- Calculate gross sale = sold_quantity * gross_price
SELECT 
	*,
    sold_quantity * gross_price AS gross_sales
FROM fact_sales_monthly fas LEFT JOIN gross_price gp 
	ON fas.product_code = gp.product_code 
    AND fas.fiscal_year = gp.fiscal_year
;
		-- Create and insert gross_sale column into fact_sales_monthly
ALTER TABLE fact_sales_monthly
DROP COLUMN gross_sale
;

ALTER TABLE fact_sales_monthly
ADD COLUMN gross_sale DECIMAL(15, 10)
;

UPDATE fact_sales_monthly AS fas
	LEFT JOIN gross_price AS gp ON fas.product_code = gp.product_code AND fas.fiscal_year = gp.fiscal_year
SET fas.gross_sale = fas.sold_quantity * gp.gross_price
;

SELECT * FROM fact_sales_monthly;

	-- net_invoice_sales
SELECT * FROM pre_invoice_deductions;

SELECT 
	*,
    sold_quantity * gross_price AS gross_sale,
    (sold_quantity * gross_price) * pre_invoice_discount_pct AS pre_invoice_discount,
    (sold_quantity * gross_price) - ((sold_quantity * gross_price) * pre_invoice_discount_pct) AS net_invoice_sale
FROM fact_sales_monthly fas LEFT JOIN gross_price gp 
	ON fas.product_code = gp.product_code 
    AND fas.fiscal_year = gp.fiscal_year LEFT JOIN pre_invoice_deductions pid
    ON fas.customer_code = pid.customer_code 
    AND fas.fiscal_year = pid.fiscal_year
;