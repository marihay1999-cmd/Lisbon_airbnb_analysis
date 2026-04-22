-- STEP 1: Create a new database for the Airbnb analytics project
-- This database will store staging tables, normalized tables,
-- and analytical tables for the Airbnb Portugal dataset

CREATE DATABASE airbnb_sql_project;

-- Step 2: Create a dedicated schema for analytical tables
-- All project tables will be stored under the analytics schema
-- instead of the default public schema

CREATE SCHEMA analytics;

-- Step 3: Enable PostGIS extension
-- PostGIS allows spatial data types and geographic functions

CREATE EXTENSION IF NOT EXISTS postgis;

-- Step 4: Create a staging table for raw Airbnb CSV data
-- This table stores the original dataset before normalization
-- It allows us to clean and transform the data before loading into dimension and fact tables

CREATE TABLE analytics.listings_raw (
    id BIGINT,
    city VARCHAR(50),
    name VARCHAR(255),
    host_id BIGINT,
    host_name VARCHAR(255),
    neighbourhood_group VARCHAR(100),
    neighbourhood VARCHAR(100),
    latitude NUMERIC(10,8),
    longitude NUMERIC(11,8),
    room_type VARCHAR(50),
    price NUMERIC(10,2),
    minimum_nights INT,
    number_of_reviews INT,
    reviews_per_month NUMERIC(4,2),
    availability_365 INT,
    number_of_reviews_ltm INT
);
-- STEP 5: Load the Lisbon Airbnb dataset into the staging table
-- The COPY command imports raw CSV data into listings_raw

COPY analytics.listings_raw
FROM '/docker-entrypoint-initdb.d/data/listings_lisbon.csv'
CSV HEADER;

-- Preview first 10 rows from raw dataset

SELECT *
FROM analytics.listings_raw
LIMIT 10;


-- STEP 7: Create the countries dimension table
-- This table stores unique countries for listings
CREATE TABLE analytics.countries (
    country_id SERIAL PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL UNIQUE
);

-- Insert Portugal into the countries table
INSERT INTO analytics.countries (country_name)
SELECT DISTINCT 'Portugal'
FROM analytics.listings_raw
ON CONFLICT (country_name) DO NOTHING;

-- STEP 8: Create the cities dimension table
-- Each city belongs to a country
CREATE TABLE analytics.cities (
    city_id SERIAL PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL UNIQUE,
    country_id INT NOT NULL REFERENCES analytics.countries(country_id),
    geom GEOMETRY(Point, 4326)  -- Optional spatial column representing city location

);

-- Insert unique cities from raw data
INSERT INTO analytics.cities (city_name, country_id)
SELECT DISTINCT TRIM(lr.city) AS city_name, c.country_id
FROM analytics.listings_raw lr
JOIN analytics.countries c ON c.country_name = 'Portugal'
WHERE lr.city IS NOT NULL
ON CONFLICT (city_name) DO NOTHING;

-- STEP 9: Create neighborhoods dimension table
-- Each neighborhood belongs to a city
CREATE TABLE analytics.neighborhoods (
    neighborhood_id SERIAL PRIMARY KEY,
    neighborhood_name VARCHAR(100) NOT NULL UNIQUE,
    city_id INT NOT NULL REFERENCES analytics.cities(city_id),
    geom GEOMETRY(Polygon, 4326) -- optional: for advanced spatial analysis
);

-- Insert unique neighborhoods
INSERT INTO analytics.neighborhoods (neighborhood_name, city_id)
SELECT DISTINCT
    COALESCE(NULLIF(TRIM(lr.neighbourhood), ''), 'Unknown Neighborhood') AS neighborhood_name,
    ci.city_id
FROM analytics.listings_raw lr
JOIN analytics.cities ci ON ci.city_name = lr.city
ON CONFLICT (neighborhood_name) DO NOTHING;

-- STEP 10: Create hosts dimension table
-- Each Airbnb host is stored once
CREATE TABLE analytics.hosts (
    host_id BIGINT PRIMARY KEY,
    host_name VARCHAR(255) NOT NULL
);

-- Insert unique hosts from listings_raw
-- Replace NULL or empty host_name with placeholder 'Unknown Host {host_id}'
--insert unique host

INSERT INTO analytics.hosts (host_id, host_name)
SELECT DISTINCT
    lr.host_id,
    COALESCE(NULLIF(TRIM(lr.host_name), ''), 'Unknown Host ' || lr.host_id) AS host_name
FROM analytics.listings_raw lr
WHERE lr.host_id IS NOT NULL
ON CONFLICT (host_id) DO NOTHING;

-- STEP 11: Create the listings table
-- This is the central table connecting hosts, cities,
-- and neighborhoods
CREATE TABLE analytics.listings (
    listing_id BIGINT PRIMARY KEY,
    city_id INT NOT NULL REFERENCES analytics.cities(city_id),
    host_id BIGINT NOT NULL REFERENCES analytics.hosts(host_id),
    neighborhood_id INT REFERENCES analytics.neighborhoods(neighborhood_id),
    room_type VARCHAR(50),
    price NUMERIC(10,2),
    minimum_nights INT,
    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),
    geom GEOMETRY(Point, 4326)   -- Spatial point representing listing location
);

-- Insert listings from listings_raw
-- Use DISTINCT ON to remove duplicates by listing_id
-- Replace NULL or empty room_type with 'Unknown Room Type'
--Insert normalized listings


INSERT INTO analytics.listings (
    listing_id, city_id, host_id, neighborhood_id, room_type, price, minimum_nights, latitude, longitude
)
SELECT DISTINCT ON (lr.id)
    lr.id AS listing_id,
    c.city_id,
    lr.host_id,
    n.neighborhood_id,
    COALESCE(NULLIF(TRIM(lr.room_type), ''), 'Unknown Room Type') AS room_type,
    lr.price,
    lr.minimum_nights,
    lr.latitude,
    lr.longitude
FROM analytics.listings_raw lr
JOIN analytics.cities c ON c.city_name = lr.city
LEFT JOIN analytics.neighborhoods n 
    ON COALESCE(NULLIF(TRIM(lr.neighbourhood), ''), 'Unknown Neighborhood') = n.neighborhood_name
ORDER BY lr.id
ON CONFLICT (listing_id) DO NOTHING;

-- STEP 12: Generate spatial POINT geometries for all listings
-- Uses longitude and latitude from listings table
-- Fallback to Lisbon city center if coordinates are missing

UPDATE analytics.listings
SET geom = ST_SetSRID(
    ST_MakePoint(
        COALESCE(longitude, -9.139), -- fallback Lisbon center
        COALESCE(latitude, 38.716)
    ),
    4326
)
WHERE geom IS NULL;
