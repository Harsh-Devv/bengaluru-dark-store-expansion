SELECT *
FROM fact_ward_metrics;

SELECT *
FROM dim_geography;

SELECT *
FROM dim_zone;

-- QUERY 1: City-wide Opportunity Ranking
WITH ward_scoring AS (
    SELECT
        f."Ward Num",
        f.Zone,
        f."Density Tier",
        ROUND(f."Population" * 1.0 / (z."Avg_Commercial_Rent_Per_SqFt" * (1 + z."Competitor_Count")), 2)::DECIMAL(10, 2) AS expansion_index
    FROM 
        fact_ward_metrics AS f
    LEFT JOIN dim_geography AS g
    ON f."Ward Num" = g."Ward Num"
    LEFT JOIN dim_zone AS z
    ON g.zone = z.zone
)

SELECT
    *,
    DENSE_RANK() OVER (ORDER BY expansion_index DESC) AS opportunity_rank
FROM
    ward_scoring
ORDER BY
    opportunity_rank ASC;

-- to isolate the top 2 highest-population wards within each zone.
WITH high_pop AS (
    SELECT
        f."Ward Num",
        f.Zone,
        f.Population,
        ROW_NUMBER() OVER (PARTITION BY Zone ORDER BY Population DESC) as ranks
    FROM fact_ward_metrics AS f
)

SELECT
    *
FROM high_pop
WHERE ranks <= 2; 

-- Query 2: Top 2 Expansion Wards per Zone

WITH ward_scoring AS (
    SELECT
       f."Ward Num",
        g."Ward Name",
        f.Zone,
        f."Density Tier",
        f.Population,
        ROUND(f."Population" * 1.0 / (z."Avg_Commercial_Rent_Per_SqFt" * (1 + z."Competitor_Count")), 2)::DECIMAL(10, 2) AS expansion_index
    FROM 
        fact_ward_metrics AS f
    LEFT JOIN dim_geography AS g
    ON f."Ward Num" = g."Ward Num"
    LEFT JOIN dim_zone AS z
    ON g.zone = z.zone
), 
ward_pop AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY Zone ORDER BY expansion_index DESC) AS ranks
    FROM
        ward_scoring

)
SELECT
    Zone,
    ranks,
    "Ward Num",
    "Ward Name",
    "Density Tier",
    Population,
    expansion_index,
FROM
    ward_pop
WHERE ranks <= 2
ORDER BY Zone, ranks;


-- Zone-Level Market Saturation vs Efficiency (Aggregation & Grouping):
-- Calculate total population, total dark store count, average rent, and Population-to-Store Ratio per zone to find under-penetrated zones
-- Query 3: Zone Market Saturation & Customer-to-Store Ratio
SELECT
    f.Zone,
    SUM(f.Population) AS total_population,
    MAX(z.Competitor_Count) AS total_dark_stores,
    MAX(z.Avg_Commercial_Rent_Per_SqFt) AS average_rent,
    ROUND(
        SUM(f.Population) * 1.0 / NULLIF(MAX(z.Competitor_Count), 0), 
        2
    )::DECIMAL(10, 2) AS population_per_store
FROM
    fact_ward_metrics AS f
LEFT JOIN dim_zone AS z
ON f.Zone = z.Zone
GROUP BY
    f.zone
ORDER BY 
    population_per_store DESC;


-- Query 4: High-Density Low-Rent Hotspot Filtering
SELECT
    f."Ward Num",
    g."Ward Name",
    f.Zone,
    f."Density Tier",
    f.Population,
    z.Avg_Commercial_Rent_Per_SqFt AS zone_rent,
    ROUND((SELECT AVG(Avg_Commercial_Rent_Per_SqFt) FROM dim_zone), 2) AS city_avg_rent
FROM fact_ward_metrics AS f
LEFT JOIN dim_geography AS g
    ON f."Ward Num" = g."Ward Num"
LEFT JOIN dim_zone AS z
    ON f.Zone = z.Zone
WHERE
    f."Density Tier" = 'High Density' 
    AND z.Avg_Commercial_Rent_Per_SqFt < (
        SELECT AVG(Avg_Commercial_Rent_Per_SqFt) FROM dim_zone
    )
ORDER BY f.Population DESC;