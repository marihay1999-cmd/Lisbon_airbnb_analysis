-- STEP 13: Create listing analytics fact table
-- This table stores review and availability metrics
CREATE TABLE analytics.listing_analytics (
    listing_id BIGINT PRIMARY KEY REFERENCES analytics.listings(listing_id),
    number_of_reviews INT,
    reviews_per_month NUMERIC(4,2),
    calculated_host_listings_count INT,
    availability_365 INT,
    number_of_reviews_ltm INT
);

-- Populate listing_analytics with safe calculations

INSERT INTO analytics.listing_analytics (
    listing_id,
    number_of_reviews,
    reviews_per_month,
    calculated_host_listings_count,
    availability_365,
    number_of_reviews_ltm
)
SELECT DISTINCT ON (l.listing_id)
    l.listing_id,
    lr.number_of_reviews,
    lr.reviews_per_month,
    COUNT(*) OVER (PARTITION BY l.host_id) AS calculated_host_listings_count,
    lr.availability_365,
    lr.number_of_reviews_ltm
FROM analytics.listings l
JOIN analytics.listings_raw lr ON l.listing_id = lr.id
ORDER BY l.listing_id
ON CONFLICT (listing_id) DO UPDATE
SET 
    number_of_reviews = EXCLUDED.number_of_reviews,
    reviews_per_month = EXCLUDED.reviews_per_month,
    calculated_host_listings_count = EXCLUDED.calculated_host_listings_count,
    availability_365 = EXCLUDED.availability_365,
    number_of_reviews_ltm = EXCLUDED.number_of_reviews_ltm;

-- STEP 14: Create a denormalized analytical table
-- This table joins all important dimensions and metrics
-- to simplify analytical queries
CREATE TABLE analytics.fact_listings AS 
SELECT l.listing_id, 
    c.city_name, 	
	n.neighborhood_name, 	
	h.host_name, 	
	l.room_type, 	
	l.price, 	
	l.minimum_nights, 	
	la.number_of_reviews, 	
	la.reviews_per_month, 	
	la.calculated_host_listings_count, 	
	la.availability_365, 	
	la.number_of_reviews_ltm, 	
	l.geom 	
FROM analytics.listings l 
JOIN analytics.cities c 
ON l.city_id = c.city_id 
LEFT JOIN analytics.neighborhoods n 
ON l.neighborhood_id = n.neighborhood_id 
JOIN analytics.hosts h 
ON l.host_id = h.host_id 
JOIN analytics.listing_analytics la 
ON l.listing_id = la.listing_id;

