-- NYC Airbnb Pricing Analysis — SQL queries (SQLite-compatible)
--
-- Table: listings, loaded from AB_NYC_2019.csv with these columns:
--   id, name, host_id, host_name, neighbourhood_group, neighbourhood,
--   latitude, longitude, room_type, price, minimum_nights,
--   availability_365, number_of_reviews, last_review, reviews_per_month
--
-- The analysis cleans first: rows with a missing or zero price are dropped
-- (499 rows, 1.0%), leaving 48,396 clean listings. Run the DELETE below
-- before the queries, or load an already-cleaned table.
-- SQLite has no MEDIAN function, so medians below use a window function
-- (ROW_NUMBER + COUNT, needs SQLite 3.25 or newer) to pick the middle
-- value of the ordered prices for each group. For even-sized groups this
-- picks the lower of the two middle values.

-- Clean the data (same step as the notebook)
-- DELETE FROM listings WHERE price IS NULL OR price <= 0;

-- 1. Listings and median price by borough
-- Expected: Manhattan 21,306 listings (44.0%), median $149; Brooklyn 19,986
-- (41.3%), median $90; Queens 11.7%, median $75; Bronx 2.2%, median $65;
-- Staten Island 0.8%, median $75.
WITH ranked AS (
    SELECT neighbourhood_group, price,
           ROW_NUMBER() OVER (PARTITION BY neighbourhood_group ORDER BY price) AS rn,
           COUNT(*) OVER (PARTITION BY neighbourhood_group) AS cnt
    FROM listings
),
medians AS (
    SELECT neighbourhood_group, price AS median_price
    FROM ranked
    WHERE rn = (cnt + 1) / 2
)
SELECT
    l.neighbourhood_group AS borough,
    COUNT(*) AS listings,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM listings), 1) AS share_pct,
    m.median_price
FROM listings AS l
JOIN medians AS m ON m.neighbourhood_group = l.neighbourhood_group
GROUP BY l.neighbourhood_group, m.median_price
ORDER BY listings DESC;

-- 2. Median price by room type
-- Expected: entire home $160, private room $70, shared room $45.
WITH ranked AS (
    SELECT room_type, price,
           ROW_NUMBER() OVER (PARTITION BY room_type ORDER BY price) AS rn,
           COUNT(*) OVER (PARTITION BY room_type) AS cnt
    FROM listings
),
medians AS (
    SELECT room_type, price AS median_price
    FROM ranked
    WHERE rn = (cnt + 1) / 2
)
SELECT
    l.room_type,
    COUNT(*) AS listings,
    m.median_price
FROM listings AS l
JOIN medians AS m ON m.room_type = l.room_type
GROUP BY l.room_type, m.median_price
ORDER BY median_price DESC;

-- 3. Share of listings owned by multi-listing hosts
-- Expected: 16,443 listings (34.0%) belong to hosts with more than one
-- listing. Biggest hosts: Sonder (NYC) 272, Blueground 180, Kazuya 103.
SELECT
    COUNT(*) AS multi_listing_host_listings,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM listings), 1) AS share_pct
FROM listings
WHERE calculated_host_listings_count > 1;

-- 4. Top neighbourhoods by listing count
SELECT
    neighbourhood,
    neighbourhood_group AS borough,
    COUNT(*) AS listings,
    ROUND(AVG(price), 2) AS avg_price
FROM listings
GROUP BY neighbourhood, neighbourhood_group
ORDER BY listings DESC
LIMIT 10;

-- 5. Average price by room type and borough
SELECT
    neighbourhood_group AS borough,
    room_type,
    COUNT(*) AS listings,
    ROUND(AVG(price), 2) AS avg_price
FROM listings
GROUP BY neighbourhood_group, room_type
ORDER BY borough, avg_price DESC;

-- 6. Demand by room type: reviews per month vs price
-- reviews_per_month is a proxy for demand, not actual bookings.
SELECT
    room_type,
    COUNT(*) AS listings,
    ROUND(AVG(price), 2) AS avg_price,
    ROUND(AVG(reviews_per_month), 2) AS avg_reviews_per_month
FROM listings
GROUP BY room_type
ORDER BY avg_reviews_per_month DESC;
