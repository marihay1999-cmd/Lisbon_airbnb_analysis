--Spatial Index
CREATE INDEX idx_neighborhood_boundaries_geom
ON analytics.neighborhood_boundaries
USING GIST (geom);

----
CREATE INDEX idx_listings_geom
ON analytics.listings
USING GIST (geom);