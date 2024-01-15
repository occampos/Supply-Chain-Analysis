USE supply_chain
;

SELECT * FROM zz_original_data
;

--		create duplicate
SELECT * 
INTO z_data 
FROM zz_original_data
;


/*
	partition data
*/

--		remaining columns to be partitioned
IF OBJECT_ID('tempdb..#partitioned_columns', 'U') IS NOT NULL 
	DROP TABLE #partitioned_columns;

SELECT name
INTO #partitioned_columns
FROM sys.columns 
WHERE object_id IN (
	OBJECT_ID('customers'), 
	OBJECT_ID('products'),
	OBJECT_ID('categories_departments'),
	OBJECT_ID('orders'),
	OBJECT_ID('orders_ratio'),
	OBJECT_ID('orders_demographic'),
	OBJECT_ID('shipping'));

IF OBJECT_ID('tempdb..#remaning_columns', 'U') IS NOT NULL 
	DROP TABLE #remaning_columns;

SELECT name
INTO #remaning_columns
FROM sys.columns 
WHERE 
	object_id = OBJECT_ID('z_data') AND 
	name NOT IN (
		SELECT * 
		FROM #partitioned_columns);

SELECT * FROM #remaning_columns
;

--		remaining data to be partitioned
DECLARE @remaining_columns_list NVARCHAR(MAX);
SELECT @remaining_columns_list = COALESCE(@remaining_columns_list + ', ', '') + name
FROM #remaning_columns;

DECLARE @remaining_data NVARCHAR(MAX);
SET @remaining_data = 'SELECT ' + @remaining_columns_list + ' FROM z_data';

EXEC sp_executesql @remaining_data
;

--		create customers table
IF OBJECT_ID('dbo.customers', 'U') IS NOT NULL
    DROP TABLE dbo.customers;

SELECT DISTINCT
	Customer_Id,
	Customer_Fname,
	Customer_Lname,
	Customer_Segment,
	Customer_Country,
	Customer_State,
	Customer_City,
	Customer_Street,
	Customer_Zipcode,
	Customer_Email,
	Customer_Password
INTO customers 
FROM z_data
;

--		create products table
IF OBJECT_ID('dbo.products', 'U') IS NOT NULL
    DROP TABLE dbo.products;

SELECT DISTINCT
	Product_Card_Id,
	Product_Name,
	Product_Category_Id,
	Department_Id,
	Product_Price,
	Product_Description,
	Product_Image,
	Product_Status
INTO products 
FROM z_data
;

--		create categories_departments table
IF OBJECT_ID('dbo.categories_departments', 'U') IS NOT NULL
    DROP TABLE dbo.categories_departments;

SELECT DISTINCT
		Category_Id,
		Category_Name,
		Department_Id,
		Department_Name
INTO categories_departments
FROM z_data
;

--		create orders table
IF OBJECT_ID('dbo.orders', 'U') IS NOT NULL
    DROP TABLE dbo.orders;

SELECT DISTINCT
	Order_Id,
	Order_Item_Id,
	Order_Customer_Id,
	order_date_DateOrders,
	Type,
	Order_Item_Cardprod_Id,
	Order_Item_Product_Price,
	Order_Item_Quantity,
	Sales,
	Order_Item_Discount_Rate,
	Order_Item_Discount,
	Order_Item_Total
INTO orders 
FROM  z_data
;

--			Order_Item_Cardprod_Id is unique product id while Order_Item_Id is unique for all rows. Orders can have multiple transactions, Order_Item_Id is a transaction id.
SELECT
	Order_Item_Cardprod_Id,
	COUNT(Order_Item_Cardprod_Id) AS n_occurences
FROM ORDERS
GROUP BY Order_Item_Cardprod_Id
ORDER BY n_occurences DESC
;

SELECT
	Order_Item_Id,
	COUNT(Order_Item_Id) AS n_occurences
FROM ORDERS
GROUP BY Order_Item_Id
ORDER BY n_occurences DESC
;

--		create orders_ratio table
IF OBJECT_ID('dbo.orders_ratio', 'U') IS NOT NULL
    DROP TABLE dbo.orders_ratio;

SELECT DISTINCT
	Order_Id,
	Order_Item_Id,
	Order_Customer_Id,
	order_date_DateOrders,
	Order_Item_Total,
	Order_Item_Profit_Ratio,
	Order_Profit_Per_Order,
	Benefit_per_order,
	Sales_per_customer
INTO orders_ratio 
FROM  z_data
;

--		create orders_demographic table
IF OBJECT_ID('dbo.orders_demographic', 'U') IS NOT NULL
    DROP TABLE dbo.orders_demographic;

SELECT DISTINCT
	Order_Id,
	Order_Item_Id,
	order_date_DateOrders,
	Type,
	Order_Customer_Id,
	Latitude,
	Longitude,
	Market,
	Order_Region,
	Order_Country,
	Order_State,
	Order_City,
	Order_Zipcode,
	Order_Status
INTO orders_demographic 
FROM  z_data
;

--		create shipping table
IF OBJECT_ID('dbo.shipping', 'U') IS NOT NULL
    DROP TABLE dbo.shipping;

SELECT DISTINCT
	Order_Id,
	Order_Item_Id,
	order_date_DateOrders,
	Order_Customer_Id,
	Order_Item_Cardprod_Id,
	shipping_date_DateOrders,
	Shipping_Mode,
	Days_for_shipment_scheduled,
	Days_for_shipping_real,
	Delivery_Status,
	Late_delivery_risk
INTO shipping 
FROM z_data
;


/*
	clean partitioned tables
		x customers
		x products
		x categories_departments
		x orders
		x orders_ratio
		orders_demographic
		shipping
*/

/* 
	clean customers table
*/

--		table information
SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'customers'
;

--		rename column names
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('customers')
;

EXEC sp_rename 'customers.Customer_Id', 'customer_id', 'COLUMN';
EXEC sp_rename 'customers.Customer_Fname', 'first_name', 'COLUMN';
EXEC sp_rename 'customers.Customer_Lname', 'last_name', 'COLUMN';
EXEC sp_rename 'customers.Customer_Segment', 'segment', 'COLUMN';
EXEC sp_rename 'customers.Customer_Country', 'country', 'COLUMN';
EXEC sp_rename 'customers.Customer_State', 'state', 'COLUMN';
EXEC sp_rename 'customers.Customer_City', 'city', 'COLUMN';
EXEC sp_rename 'customers.Customer_Street', 'street', 'COLUMN';
EXEC sp_rename 'customers.Customer_Zipcode', 'zipcode', 'COLUMN';
EXEC sp_rename 'customers.Customer_Email', 'email', 'COLUMN';
EXEC sp_rename 'customers.Customer_Password', 'password', 'COLUMN'
;

--		check for error (?) in characters, there are none
DECLARE @char_error CHAR(1) = '?';

SELECT *
FROM customers
WHERE EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'customers'
        AND DATA_TYPE IN ('NVARCHAR')
        AND CHARACTER_MAXIMUM_LENGTH >= LEN(@char_error)
        AND (
            CHARINDEX(@char_error, first_name) > 0 OR
            CHARINDEX(@char_error, last_name) > 0 OR
			CHARINDEX(@char_error, segment) > 0 OR
			CHARINDEX(@char_error, country) > 0 OR
			CHARINDEX(@char_error, state) > 0 OR
			CHARINDEX(@char_error, street) > 0 OR
			CHARINDEX(@char_error, zipcode) > 0 OR
			CHARINDEX(@char_error, email) > 0 OR
			CHARINDEX(@char_error, password) > 0
			)
	)
;

--		check for duplicate rows, there are none
SELECT 
	customer_id, 
	COUNT(*)
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1
;

--		search for errors
SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'customers'
;

--			input error for customer ids: (14046,17171,14577)
SELECT DISTINCT 
	state,
	COUNT(*) as n
FROM customers
GROUP BY state
ORDER BY n ASC
;

SELECT 
	street,
	LEN(street) as len
FROM customers
ORDER BY len DESC
;

SELECT 
	state,
	LEN(state) as len
FROM customers
ORDER BY len DESC
;

SELECT 
	city,
	LEN(city) as len
FROM customers
ORDER BY len ASC
;

SELECT 
	zipcode,
	LEN(zipcode) as len
FROM customers
ORDER BY len ASC
;

SELECT
	zipcode,
	COUNT(*) as n
FROM customers
GROUP BY zipcode
ORDER BY n DESC
;

SELECT * 
FROM customers
WHERE zipcode = 725
;

--			fixing data input error
SELECT 
	customer_id,
	country,
	city,
	state
FROM customers
ORDER BY 
	state
;

SELECT *
FROM customers
WHERE customer_id IN (14046,17171,14577)
;

UPDATE customers
SET zipcode = state
WHERE customer_id IN (14046,17171,14577)
;

UPDATE customers
SET state = city
WHERE customer_id IN (14046,17171,14577)
;

SELECT *
FROM customers
WHERE zipcode IN (91732,95758)
;

UPDATE customers
SET city = street
WHERE customer_id IN (14046,17171,14577)
;

UPDATE customers
SET street = NULL
WHERE customer_id IN (14046,17171,14577)
;

--		check for null values, null names and street will be left as 
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('customers')
;

SELECT *
FROM customers
WHERE 
	customer_id IS NULL OR
	first_name IS NULL OR
	last_name IS NULL OR
	segment IS NULL OR
	country IS NULL OR
	state IS NULL OR
	city IS NULL OR
	street IS NULL OR
	zipcode IS NULL OR
	email IS NULL OR
	password IS NULL
;

--		drop email and password from table, all entries are 'XXXXXXXXX'
SELECT DISTINCT email
FROM customers
;
SELECT DISTINCT password
FROM customers
;

ALTER TABLE customers
DROP COLUMN 
	email, 
	password
;

--		select
SELECT * FROM customers
;

/* 
	clean products table
*/

--		table information
SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'products'
;

--		rename column names
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('products')
;

EXEC sp_rename 'products.Product_Card_Id', 'product_id', 'COLUMN';
EXEC sp_rename 'products.Product_Name', 'product_name', 'COLUMN';
EXEC sp_rename 'products.Product_Category_Id', 'category_id', 'COLUMN';
EXEC sp_rename 'products.Department_Id', 'department_id', 'COLUMN';
EXEC sp_rename 'products.Product_Price', 'price', 'COLUMN';
EXEC sp_rename 'products.Product_Description', 'description', 'COLUMN';
EXEC sp_rename 'products.Product_Image', 'product_image', 'COLUMN';
EXEC sp_rename 'products.Product_Status', 'product_status', 'COLUMN';
;

--		check for duplicate rows, there are none
SELECT 
	product_id, 
	COUNT(*)
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1
;

SELECT 
	product_name, 
	COUNT(*)
FROM products
GROUP BY product_name
HAVING COUNT(*) > 1
;

SELECT 
	product_image, 
	COUNT(*)
FROM products
GROUP BY product_image
HAVING COUNT(*) > 1
;

--		search for errors, none found
SELECT *
FROM products
ORDER BY product_name DESC
;

SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'products'
;

--		drop description and product_status, no usable data
SELECT 
	description,
	COUNT(*)
FROM products
GROUP BY description
;

SELECT 
	product_status,
	COUNT(*)
FROM products
GROUP BY product_status
;

ALTER TABLE products
DROP COLUMN 
	description, 
	product_status
;

--		check for null values, no null values
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('products')
;

SELECT *
FROM products
WHERE 
	product_id IS NULL OR
	product_name IS NULL OR
	category_id IS NULL OR
	department_id IS NULL OR
	price IS NULL OR
	product_image IS NULL
;

--		change price to decimal for accuracy with two decimal spots, save original price in seperate table
--			save original price in seperate table
IF OBJECT_ID('dbo.price_history', 'U') IS NOT NULL
    DROP TABLE dbo.price_history;

SELECT
	ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as price_history_id,
	product_id,
	price,
	GETDATE() AS update_date
INTO price_history
FROM products
;

SELECT *
FROM price_history
;

SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'price_history'
;

ALTER TABLE price_history
ALTER COLUMN price_history_id INT
;

--			change price to decimal for accuracy with two decimal spots
ALTER TABLE products
ALTER COLUMN price DECIMAL(10, 2)
;

SELECT
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'products'
;

--		select
SELECT * FROM products
;

/* 
	clean categories_departments table
*/

--		table information
SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'categories_departments'
;

--		rename column names
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('categories_departments')
;

EXEC sp_rename 'categories_departments.Category_Id', 'category_id', 'COLUMN';
EXEC sp_rename 'categories_departments.Category_Name', 'category', 'COLUMN';
EXEC sp_rename 'categories_departments.Department_Id', 'department_id', 'COLUMN';
EXEC sp_rename 'categories_departments.Department_Name', 'department', 'COLUMN';
;

--		check for duplicate rows, there are none
SELECT 
	category_id, 
	COUNT(*)
FROM categories_departments
GROUP BY category_id
HAVING COUNT(*) > 1
;

--			electronics is present in two rows, due to both footwear and outdoors department have electronics category 
SELECT 
	category, 
	COUNT(*)
FROM categories_departments
GROUP BY category
HAVING COUNT(*) > 1
;

SELECT *
FROM categories_departments
WHERE category = 'Electronics'
;

--		search for errors, none found
SELECT *
FROM categories_departments
ORDER BY category DESC
;

SELECT *
FROM categories_departments
ORDER BY department DESC
;

SELECT 
	category,
	COUNT(*) AS n
FROM categories_departments
GROUP BY category
ORDER BY n DESC
;

SELECT *
FROM categories_departments
ORDER BY category DESC
;

--		check for null values, no null values
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('categories_departments')
;

SELECT *
FROM categories_departments
WHERE 
	category_id IS NULL OR
	category IS NULL OR
	department_id IS NULL OR
	department IS NULL 
;

--		select
SELECT * 
FROM categories_departments
;

/* 
	clean orders table
*/

--		table information
SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'orders'
;

--		rename column names
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('orders')
;

EXEC sp_rename 'orders.Order_Id', 'order_id', 'COLUMN'
EXEC sp_rename 'orders.Order_Item_Cardprod_Id', 'product_id', 'COLUMN'
EXEC sp_rename 'orders.order_date_DateOrders', 'order_date', 'COLUMN'
EXEC sp_rename 'orders.Type', 'payment_type', 'COLUMN'
EXEC sp_rename 'orders.Order_Customer_Id', 'customer_id', 'COLUMN'
EXEC sp_rename 'orders.Order_Item_Id', 'transaction_id', 'COLUMN'
EXEC sp_rename 'orders.Order_Item_Product_Price', 'price', 'COLUMN'
EXEC sp_rename 'orders.Order_Item_Quantity', 'quantity', 'COLUMN'
EXEC sp_rename 'orders.Order_Item_Discount_Rate', 'discount_pct', 'COLUMN'
EXEC sp_rename 'orders.Order_Item_Discount', 'discount', 'COLUMN'
EXEC sp_rename 'orders.Sales', 'gross_sale', 'COLUMN'
EXEC sp_rename 'orders.Order_Item_Total', 'net_sale', 'COLUMN'
;

--		change order_date datatypes to datetime
ALTER TABLE orders
ALTER COLUMN order_date DATETIME
;

--		change datatypes to decimal
ALTER TABLE orders
ALTER COLUMN price DECIMAL(10,2);
ALTER TABLE orders
ALTER COLUMN gross_sale DECIMAL(10,2);
ALTER TABLE orders
ALTER COLUMN discount DECIMAL(10,2);
ALTER TABLE orders
ALTER COLUMN net_sale DECIMAL(10,2);
;


--		check prices against products
IF OBJECT_ID('tempdb..#check_price', 'U') IS NOT NULL 
	DROP TABLE #check_price;

SELECT *
INTO #check_price
FROM 
	(SELECT
		product_id AS o_product_id,
		price AS o_price
	FROM orders) o LEFT OUTER join products p ON o.o_product_id=p.product_id
;

--			check nulls, no nulls, all products in orders table are present in products table
SELECT *
FROM #check_price
WHERE 
	o_product_id IS NULL OR
	o_price IS NULL OR
	category_id IS NULL OR
	product_id IS NULL
;

--			price match, all prices in orders table match with prices in products table
SELECT DISTINCT
	o_product_id,
	o_price,
	product_id,
	price,
	o_price - price AS diff
FROM 
	(SELECT
		product_id AS o_product_id,
		price AS o_price
	FROM orders) o join products p ON o.o_product_id=p.product_id
WHERE o_price - price > 0
; 

--		check if changing columsn to decimals(10,2) created accounting error
IF OBJECT_ID('tempdb..#decimal_check', 'U') IS NOT NULL 
	DROP TABLE #decimal_check;

SELECT
	transaction_id,
	price,
	quantity,
	discount_pct,
	CAST((price * quantity) * discount_pct AS DECIMAL(10,2)) AS  test,
	discount
INTO #decimal_check
FROM orders
;

--			discount_pct and resulting dicount are wrong for all rows with discount_pct = 0.059999999 
SELECT *
FROM #decimal_check
WHERE test != discount
;

SELECT COUNT(*)
FROM #decimal_check
WHERE test != discount;
;

SELECT COUNT(*)
FROM orders
WHERE discount_pct = 0.059999999
;

--			fix error by updating discount_pct to 0.055013753 
SELECT transaction_id
FROM orders
WHERE discount_pct = 0.059999999
;

UPDATE orders
SET discount_pct = 0.055013753
WHERE transaction_id IN (SELECT transaction_id
						FROM orders
						WHERE discount_pct = 0.059999999)
;

--		check if changing columsn to decimals(10,2) created accounting error
IF OBJECT_ID('tempdb..#decimal_check', 'U') IS NOT NULL 
	DROP TABLE #decimal_check;

SELECT
	transaction_id,
	price,
	quantity,
	discount,
	CAST((price * quantity) AS DECIMAL(10,2)) AS  test,
	gross_sale
INTO #decimal_check
FROM orders
;

SELECT *
FROM #decimal_check
WHERE test != gross_sale
;

IF OBJECT_ID('tempdb..#decimal_check', 'U') IS NOT NULL 
	DROP TABLE #decimal_check;

SELECT
	transaction_id,
	price,
	quantity,
	discount,
	gross_sale,
	CAST(gross_sale - discount AS DECIMAL(10,2)) AS  test,
	net_sale
INTO #decimal_check
FROM orders
;

--		some net_sales are off by 0.01
SELECT *
FROM #decimal_check
WHERE test != net_sale
;

SELECT transaction_id
FROM #decimal_check
WHERE test != net_sale
;

WITH cte AS (
	SELECT
		*,
		net_sale - test AS diff
	FROM #decimal_check
	WHERE test != net_sale)
SELECT *
FROM cte
WHERE diff != 0.01
;

--		fix error by subtracting 0.01 to corresponding net sales
UPDATE orders
SET net_sale = net_sale - 0.01
WHERE transaction_id IN (SELECT transaction_id
						FROM #decimal_check
						WHERE test != net_sale)
;

--	select
SELECT * FROM orders
;

/* 
	clean orders_ratio table
*/

--		table information
SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'orders_ratio'
;

--		rename column names
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('orders_ratio')
;

EXEC sp_rename 'orders_ratio.Order_Id', 'order_id', 'COLUMN';
EXEC sp_rename 'orders_ratio.Order_Item_Id', 'transaction_id', 'COLUMN';
EXEC sp_rename 'orders_ratio.Order_Customer_Id', 'customer_id', 'COLUMN';
EXEC sp_rename 'orders_ratio.order_date_DateOrders', 'order_date', 'COLUMN';
EXEC sp_rename 'orders_ratio.Order_Item_Total', 'net_sale', 'COLUMN';
EXEC sp_rename 'orders_ratio.Order_Item_Profit_Ratio', 'item_profit_ratio', 'COLUMN';
EXEC sp_rename 'orders_ratio.Order_Profit_Per_Order', 'profit_per_order', 'COLUMN';
EXEC sp_rename 'orders_ratio.Benefit_per_order', 'benefit_per_order', 'COLUMN';
EXEC sp_rename 'orders_ratio.Sales_per_customer', 'sales_per_customer', 'COLUMN';
;

--		change order_date datatypes to datetime
ALTER TABLE orders_ratio
ALTER COLUMN order_date DATETIME
;

--		change datatypes to decimal
ALTER TABLE orders_ratio
ALTER COLUMN net_sale DECIMAL(10,2);
;

--		some net_sales are off by 0.01
--		fix error by subtracting 0.01 to corresponding net sales
WITH cte AS (
	SELECT
		o.transaction_id,
		o.net_sale as o,
		r.net_sale as r
	FROM orders o join orders_ratio r on o.transaction_id = r.transaction_id)
SELECT *
FROM cte
WHERE o != r

WITH cte AS (
	SELECT
		o.transaction_id,
		o.net_sale as o,
		r.net_sale as r
	FROM orders o join orders_ratio r on o.transaction_id = r.transaction_id)
SELECT transaction_id
INTO #error_transaction_id
FROM cte
WHERE o != r

UPDATE orders_ratio
SET net_sale = net_sale - 0.01
WHERE transaction_id IN (SELECT transaction_id
						FROM #error_transaction_id)
;

--	select
SELECT * FROM orders_ratio
;

/* 
	clean orders_demographic table
*/

--		table information
SELECT 
	column_name, 
	data_type, 
	character_maximum_length
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'orders_demographic'
;

--		rename column names
SELECT name
FROM sys.columns 
WHERE object_id = OBJECT_ID('orders_demographic')
;

EXEC sp_rename 'orders_demographic.Order_Id', 'order_id', 'COLUMN';
EXEC sp_rename 'orders_demographic.order_date_DateOrders', 'order_date', 'COLUMN';
EXEC sp_rename 'orders_demographic.Type', 'type', 'COLUMN';
EXEC sp_rename 'orders_demographic.Order_Item_Id', 'transaction_id', 'COLUMN';
EXEC sp_rename 'orders_demographic.Order_Customer_Id', 'customer_id', 'COLUMN';
EXEC sp_rename 'orders_demographic.Latitude', 'latitiude', 'COLUMN';
EXEC sp_rename 'orders_demographic.Longitude', 'longitude', 'COLUMN';
EXEC sp_rename 'orders_demographic.Market', 'market', 'COLUMN';
EXEC sp_rename 'orders_demographic.Order_Region', 'region', 'COLUMN';
EXEC sp_rename 'orders_demographic.Order_Country', 'country', 'COLUMN';
EXEC sp_rename 'orders_demographic.Order_State', 'state', 'COLUMN';
EXEC sp_rename 'orders_demographic.Order_City', 'city', 'COLUMN';
EXEC sp_rename 'orders_demographic.Order_Zipcode', 'zipcode', 'COLUMN';
EXEC sp_rename 'orders_demographic.Order_Status', 'order_status', 'COLUMN';
;


--	select
SELECT * FROM orders_demographic
;











	-- check for error (?) in characters, there are none
DECLARE @char_error CHAR(1) = '?';

SELECT *
FROM orders_demographic
WHERE EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = 'orders_demographic'
        AND DATA_TYPE IN ('NVARCHAR')
        AND CHARACTER_MAXIMUM_LENGTH >= LEN(@char_error)
        AND (
            CHARINDEX(@char_error, Type) > 0 OR
            CHARINDEX(@char_error, market) > 0 OR
			CHARINDEX(@char_error, region) > 0 OR
			CHARINDEX(@char_error, country) > 0 OR
			CHARINDEX(@char_error, state) > 0 OR
			CHARINDEX(@char_error, city) > 0 OR
			CHARINDEX(@char_error, zipcode) > 0 OR
			CHARINDEX(@char_error, order_status) > 0 
        )
);