-- SQL statement to join dim_customers with dim_geography to enrich customer data with geographic information

SELECT 
    c.CustomerID,  
    c.CustomerName,  
    c.Email,  
    c.Gender,  
    c.Age,  
    g.Country,  
    g.City  
FROM 
    dbo.customers as c  -- Specifies the alias 'c' for the dim_customers table
LEFT JOIN

    dbo.geography g  -- Specifies the alias 'g' for the dim_geography table
ON 
    c.GeographyID = g.GeographyID;  -- Joins the two tables on the GeographyID field to match customers with their geographic information



-- SQL Query to categorize products based on their price

SELECT 
    ProductID,  
    ProductName,  
    Price,  

    CASE -- Categorizes the products into price categories: Low, Medium, or High
        WHEN Price < 50 THEN 'Low'  -- If the price is less than 50, categorize as 'Low'
        WHEN Price BETWEEN 50 AND 200 THEN 'Medium'  -- If the price is between 50 and 200 (inclusive), categorize as 'Medium'
        ELSE 'High'  -- If the price is greater than 200, categorize as 'High'
    END AS PriceCategory  -- Names the new column as PriceCategory

FROM 
    dbo.products;  -- Specifies the source table from which to select the data


-- Query to clean whitespace issues in the ReviewText column

SELECT 
    ReviewID,  
    CustomerID,  
    ProductID,  
    ReviewDate,  
    Rating,
    -- Cleans up the ReviewText by replacing double spaces with single spaces to ensure the text is more readable and standardized
    REPLACE(ReviewText, '  ', ' ') AS ReviewText
FROM 
    dbo.customer_reviews;  -- Specifies the source table from which to select the data


-- Query to clean and normalize the engagement_data table

SELECT 
    EngagementID,  
    ContentID,  
	CampaignID,  
    ProductID,  
    UPPER(REPLACE(ContentType, 'Socialmedia', 'Social Media')) AS ContentType,  -- Replaces "Socialmedia" with "Social Media" and then converts all ContentType values to uppercase
    LEFT(ViewsClicksCombined, CHARINDEX('-', ViewsClicksCombined) - 1) AS Views,  -- Extracts the Views part from the ViewsClicksCombined column by taking the substring before the '-' character
    RIGHT(ViewsClicksCombined, LEN(ViewsClicksCombined) - CHARINDEX('-', ViewsClicksCombined)) AS Clicks,  -- Extracts the Clicks part from the ViewsClicksCombined column by taking the substring after the '-' character
    Likes,  -- Selects the number of likes the content received
    -- Converts the EngagementDate to the dd.mm.yyyy format
    FORMAT(CONVERT(DATE, EngagementDate), 'dd.MM.yyyy') AS EngagementDate  -- Converts and formats the date as dd.mm.yyyy
FROM 
    dbo.engagement_data  -- Specifies the source table from which to select the data
WHERE 
    ContentType != 'Newsletter';  -- Filters out rows where ContentType is 'Newsletter' as these are not relevant for our analysis


-- Common Table Expression (CTE) to identify and tag duplicate records

WITH DuplicateRecords AS (
    SELECT 
        JourneyID,  
        CustomerID, 
        ProductID,  
        VisitDate,  
        Stage,  
        Action,  
        Duration,  
        -- Use ROW_NUMBER() to assign a unique row number to each record within the partition defined below
        ROW_NUMBER() OVER (
            -- PARTITION BY groups the rows based on the specified columns that should be unique
            PARTITION BY CustomerID, ProductID, VisitDate, Stage, Action  
            
            ORDER BY JourneyID  
        ) AS row_num  
    FROM 
        dbo.customer_journey  
)

-- Select all records from the CTE where row_num > 1, which indicates duplicate entries
    
SELECT *
FROM DuplicateRecords
-- WHERE row_num > 1  -- Filters out the first occurrence (row_num = 1) and only shows the duplicates (row_num > 1)
ORDER BY JourneyID

-- Outer query selects the final cleaned and standardized data
    
SELECT 
    JourneyID,  
    CustomerID,  
    ProductID,  
    VisitDate,  
    Stage,  
    Action,  
    COALESCE(Duration, avg_duration) AS Duration  -- Replaces missing durations with the average duration for the corresponding date
FROM 
    (
        -- Subquery to process and clean the data
        SELECT 
            JourneyID, 
            CustomerID,  
            ProductID,  
            VisitDate,  
            UPPER(Stage) AS Stage,  
            Action,  -- Selects the action taken by the customer (e.g., View, Click, Purchase)
            Duration,  
            AVG(Duration) OVER (PARTITION BY VisitDate) AS avg_duration,  
            ROW_NUMBER() OVER (
                PARTITION BY CustomerID, ProductID, VisitDate, UPPER(Stage), Action  
                ORDER BY JourneyID  
            ) AS row_num  
        FROM 
            dbo.customer_journey  
    ) AS subquery  
WHERE 
    row_num = 1;


