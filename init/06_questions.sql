
--1. Which neighborhoods have the highest average listing prices?
SELECT 
    n.neighborhood_name,
    ROUND(AVG(l.price), 2) AS avg_price,
    COUNT(l.listing_id) AS total_listings
FROM analytics.listings l
LEFT JOIN analytics.neighborhoods n
    ON l.neighborhood_id = n.neighborhood_id
GROUP BY n.neighborhood_name
HAVING COUNT(l.listing_id) > 100
ORDER BY avg_price DESC;

--2. What is the distriubution of listings by room type? 
SELECT 
    l.room_type,
    COUNT(*) AS total_listings,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 
        2
    ) AS percentage_share
FROM analytics.listings l
GROUP BY l.room_type
ORDER BY total_listings DESC;

--3. Which hosts manage the largest number of listings? 
SELECT 
    h.host_id,
    h.host_name,
    COUNT(l.listing_id) AS total_listings,
    RANK() OVER (ORDER BY COUNT(l.listing_id) DESC) AS host_rank
FROM analytics.hosts h
JOIN analytics.listings l
    ON h.host_id = l.host_id
GROUP BY h.host_id, h.host_name
ORDER BY total_listings DESC
LIMIT 10;

--4. Which neighborhoods receive the most reviews? 
SELECT 
    n.neighborhood_name,
    SUM(la.number_of_reviews) AS total_reviews,
    ROUND(AVG(la.number_of_reviews), 2) AS avg_reviews_per_listing
FROM analytics.listings l
JOIN analytics.neighborhoods n
    ON l.neighborhood_id = n.neighborhood_id
JOIN analytics.listing_analytics la
    ON l.listing_id = la.listing_id
GROUP BY n.neighborhood_name
ORDER BY total_reviews DESC
LIMIT 10;

--5. How does price vary across room types?
SELECT 
    l.room_type,
    ROUND(AVG(l.price), 2) AS avg_price,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY l.price) AS median_price,
    MIN(l.price) AS min_price,
    MAX(l.price) AS max_price,
    COUNT(*) AS total_listings
FROM analytics.listings l
GROUP BY l.room_type
ORDER BY avg_price DESC;

--6. Which neighborhoods have the highest listing density per km²?
SELECT 
    nb.neighborhood_name,
    COUNT(l.listing_id) AS total_listings,
    ROUND(
        (ST_Area(nb.geom::geography) / 1000000)::numeric, 2
    ) AS area_km2,
    ROUND(
        (COUNT(l.listing_id) / NULLIF(ST_Area(nb.geom::geography) / 1000000, 0))::numeric, 2
    ) AS listings_per_km2,
	nb.geom --քարտեզի համար
FROM analytics.neighborhood_boundaries nb
LEFT JOIN analytics.listings l
    ON ST_Intersects(l.geom, nb.geom)
GROUP BY nb.neighborhood_name, nb.geom
ORDER BY listings_per_km2 DESC NULLS LAST
LIMIT 10;
