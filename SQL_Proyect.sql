---- Sales Performance Over Time

SELECT FORMAT(order_date,'yyyy-MM') AS Date,
SUM(sales_amount) AS Total_Sales,
COUNT(DISTINCT customer_key) AS Total_Customers,
SUM(quantity) AS Total_Quantity
FROM dbo.fact_sales
WHERE FORMAT(order_date,'yyyy-MM') IS NOT NULL
GROUP BY FORMAT(order_date,'yyyy-MM')
ORDER BY FORMAT(order_date,'yyyy-MM') DESC


---- Total Sales Per Month And The Running Total Of Sales Over Time 

SELECT 
Date,
Total_Sales,
SUM(Total_Sales) OVER(ORDER BY Date) AS Running_total_Sales,
Avg_Price
FROM (
SELECT 
DATETRUNC(year,order_date) AS Date,
SUM(sales_amount) AS Total_Sales,
AVG(price) AS Avg_Price
FROM dbo.fact_sales
WHERE DATETRUNC(year,order_date) IS NOT NULL
GROUP BY DATETRUNC(year,order_date)
) T

---- Yearly Performance of Products by Comparing Each Product's Sales Both Average and The Previous Year's Sale

WITH Yearly_Sales_per_Product AS (
SELECT 
YEAR(S.order_date) as Order_Date,
P.product_name As Prodcut_Name,
SUM(S.sales_amount) AS Current_Sales
FROM dbo.fact_sales S
JOIN gold.dim_products P
ON S.product_key = P.product_key
WHERE YEAR(order_date) IS NOT NULL
GROUP BY YEAR(order_date), P.product_name 
)

SELECT 
Order_Date,
Prodcut_Name,
Current_Sales,
AVG(Current_Sales) OVER (PARTITION BY Prodcut_Name) AS Avg_Sales,
Current_Sales - AVG(Current_Sales) OVER (PARTITION BY Prodcut_Name) AS Difference_Avg_Sales,
CASE WHEN Current_Sales - AVG(Current_Sales) OVER (PARTITION BY Prodcut_Name) < 0 THEN 'Below Average'
WHEN Current_Sales - AVG(Current_Sales) OVER (PARTITION BY Prodcut_Name) > 0 THEN 'Above Average'
ELSE 'Average'
END AS Average_Change,
Current_Sales - LAG(Current_Sales) OVER(PARTITION BY Prodcut_Name ORDER BY Order_Date) AS Difference_Yearly_Sales,
CASE WHEN Current_Sales - LAG(Current_Sales) OVER(ORDER BY Order_Date) < 0 THEN 'Declining'
WHEN Current_Sales - LAG(Current_Sales) OVER(ORDER BY Order_Date) > 0 THEN 'Growing'
ELSE 'No Change'
END AS Yearly_Growth
FROM Yearly_Sales_per_Product
ORDER BY Prodcut_Name


---- Which Ctaegories Contribute The Most To Overall Sales.

WITH Category_Sales AS (
SELECT 
P.category As Product_Category,
SUM(S.sales_amount) AS Total_Sales
FROM dbo.fact_sales S
JOIN gold.dim_products P
ON S.product_key = P.product_key
GROUP BY  P.category
)

SELECT
Product_Category,
Total_Sales,
SUM(Total_Sales) OVER(ORDER BY Product_Category) AS Total_Store_Sales,
CONCAT(ROUND((CAST (Total_Sales as float) /SUM(Total_Sales) OVER())*100,2),'%') As Porcentage_Sales
FROM Category_Sales
Group BY Total_Sales,Product_Category
ORDER BY Porcentage_Sales DESC


----- Segment Products Into Cost Ranges and Count How Many Products Fall Into Each Segment

WITH Range_Product_Cost AS (
SELECT 
P.product_key,
P.product_name AS Product_Name,
SUM(S.sales_amount) AS Total_Sales,
P.cost As Product_Range,
CASE WHEN P.cost BETWEEN 0 AND 100 THEN 'Cheap'
WHEN P.cost BETWEEN 100 AND 800 THEN 'Average'
WHEN P.cost BETWEEN 800 AND 1200 THEN 'Medium'
ELSE 'Expensive'
END AS Product_Price
FROM dbo.fact_sales S
JOIN gold.dim_products P
	ON S.product_key = P.product_key
GROUP BY P.product_name,P.cost, P.product_key
)


SELECT
Product_Price,
COUNT(product_key) AS Count_Products 
FROM Range_Product_Cost
GROUP BY Product_Price
ORDER BY Product_Price


--- Customers Group Based on Their Spending Behavior.


WITH Customer_Time AS 
(
SELECT
C.customer_key AS Customer_ID,
SUM(S.sales_amount) AS Total_Spend,
MIN(S.order_date) AS First_Order,
MAX(S.order_date) AS Last_Order,
DATEDIFF(month,MIN(S.order_date),MAX(S.order_date)) AS Time_As_Customer
FROM dbo.fact_sales S
JOIN gold.dim_customers C
	ON  S.customer_key = C.customer_key
WHERE order_date IS NOT NULL
GROUP BY C.customer_key
)

SELECT
Class_Customer,
COUNT(Customer_ID) AS Total_Customers
FROM (
	SELECT Customer_ID,
	CASE WHEN Time_As_Customer >= 12 AND Total_Spend > 5000 THEN 'VIP'
	WHEN Time_As_Customer >= 12 AND Total_Spend  <= 5000 THEN 'Regular'
	WHEN Time_As_Customer BETWEEN 1 AND  11 AND Total_Spend  >= 1500 THEN 'Potential VIP'
	WHEN Time_As_Customer < 12  THEN 'New'
	END AS Class_Customer
	FROM Customer_Time ) t
GROUP BY Class_Customer
ORDER BY Total_Customers DESC 






