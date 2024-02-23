-- Combine databases into one database, copy all tables in gdb056 into gdb041
SET SQL_SAFE_UPDATES = 0;
SHOW PROCESSLIST;

USE gdb041;
USE gdb056;

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
    pre_invoice_discount_pct DECIMAL(15,10))
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

	-- post_invoice_deductions
SELECT * FROM post_invoice_deductions;

SELECT DISTINCT
	date,
	MONTH(date) AS month_number,
    CASE WHEN MONTH(date) >=9 THEN DATE_ADD(date, INTERVAL 4 MONTH) ELSE date END AS fiscal_date
FROM post_invoice_deductions
;

ALTER TABLE post_invoice_deductions
ADD COLUMN fiscal_date DATE
;

UPDATE post_invoice_deductions
SET fiscal_date =  CASE WHEN MONTH(date) >=9 THEN DATE_ADD(date, INTERVAL 4 MONTH) ELSE date END
;

-- Create indexes

	-- Check for existing indexes to avoid duplicates
SELECT
    table_name,
    index_name,
    GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns,
    index_type
FROM
    information_schema.statistics
WHERE
    table_schema = 'gdb041'
GROUP BY
    table_name, index_name
;

		-- dim_customer
SELECT * FROM dim_customer;
  
CREATE UNIQUE INDEX dim_customer_customer_code ON dim_customer (customer_code);

		-- dim_market
SELECT * FROM dim_market;

CREATE UNIQUE INDEX dim_market_market ON dim_market (market);

		-- dim_product
SELECT * FROM dim_product;
  
CREATE UNIQUE INDEX dim_product_product_code ON dim_product (product_code);

		-- fact_forecast_monthly
SELECT * FROM fact_forecast_monthly;

CREATE INDEX forecast_product_code_customer_code_fiscal_year ON fact_forecast_monthly (product_code, customer_code, fiscal_year);
CREATE INDEX forecast_product_code_fiscal ON fact_forecast_monthly (product_code, fiscal_year);
CREATE INDEX forecast_customer_code_fiscal ON fact_forecast_monthly (customer_code, fiscal_year);
   
		-- fact_sales_monthly
SELECT * FROM fact_sales_monthly;

CREATE INDEX sales_product_code_customer_code_fiscal_year ON fact_sales_monthly (product_code, customer_code, fiscal_year);
CREATE INDEX sales_product_code_fiscal ON fact_sales_monthly (product_code, fiscal_year);
CREATE INDEX sales_customer_code_fiscal ON fact_sales_monthly (customer_code, fiscal_year);

		-- freight_cost
SELECT * FROM freight_cost;

CREATE INDEX freight_cost_market_fiscal ON freight_cost (market, fiscal_year);

		-- gross_price
SELECT * FROM gross_price;

CREATE INDEX gross_price_product_code_fiscal ON gross_price (product_code, fiscal_year);

		-- manufacturing_cost
SELECT * FROM manufacturing_cost;

CREATE INDEX manufacturing_product_code_cost_year ON manufacturing_cost (product_code, cost_year);

		-- post_invoice_deductions
SELECT * FROM post_invoice_deductions;

CREATE INDEX post_invoice_customer_product ON post_invoice_deductions (customer_code, product_code, fiscal_date);

		-- pre_invoice_deductions
SELECT * FROM pre_invoice_deductions;

CREATE INDEX pre_invoice_customer ON pre_invoice_deductions (customer_code, fiscal_year);

	-- Check duplicate indexes
SELECT
    table_name,
    index_name,
    GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns,
    index_type
FROM
    information_schema.statistics
WHERE
    table_schema = 'gdb041'
GROUP BY
    table_name, index_name
;
    
-- Add calculated columns in fact_sales_monthly: gross_sales, net_invoice_sales, net_sales, cost_of_goods, gross_margin, net_profit

	-- Calculate gross_sale = sold_quantity * gross_price
SELECT * FROM fact_sales_monthly;
SELECT * FROM gross_price;

SELECT 
	*,
    ROUND(sold_quantity * gross_price, 15) AS gross_sale
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
SET fas.gross_sale = CAST((sold_quantity * gross_price) AS DECIMAL(15, 10))
;

	-- Calculate net_invoice_sales = gross_sale - (gross_sale * pre_invoice_discount_amount)
SELECT * FROM fact_sales_monthly;
SELECT * FROM pre_invoice_deductions;

SELECT 
	*,
    gross_sale * pre_invoice_discount_pct AS pre_invoice_discount_amount,
    gross_sale - (gross_sale * pre_invoice_discount_pct) AS net_invoice_sale
FROM fact_sales_monthly fas LEFT JOIN pre_invoice_deductions pid
    ON fas.customer_code = pid.customer_code 
    AND fas.fiscal_year = pid.fiscal_year
;

		-- Create and insert gross_sale column into fact_sales_monthly
ALTER TABLE fact_sales_monthly
DROP COLUMN net_invoice_sale
;

ALTER TABLE fact_sales_monthly
ADD COLUMN net_invoice_sale DECIMAL(15, 10)
;

UPDATE fact_sales_monthly AS fas
	LEFT JOIN pre_invoice_deductions pid
    ON fas.customer_code = pid.customer_code 
    AND fas.fiscal_year = pid.fiscal_year
SET fas.net_invoice_sale = CAST((gross_sale - (gross_sale * pre_invoice_discount_pct)) AS DECIMAL(15, 10))
;

	-- Calculate net_sale = net_invoice_sale -
SELECT * FROM fact_sales_monthly;
SELECT FROM post_invoice_deductions;

SELECT 
	*
FROM fact_sales_monthly fas LEFT JOIN post_invoice_deductions pod
	ON fas.fiscal_year = (SELECT YEAR(pod.fiscal_date) FROM post_invoice_deductions) 
	AND fas.product_code = pod.product_code
	AND fas.customer_code = pod.customer_code