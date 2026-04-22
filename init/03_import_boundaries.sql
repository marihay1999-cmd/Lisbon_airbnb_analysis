
-- Create table for Lisbon neighborhood boundaries

CREATE TABLE analytics.neighborhood_boundaries (
    id SERIAL PRIMARY KEY,
    neighborhood_name TEXT,
    geom GEOMETRY(MultiPolygon, 4326) 
);

-------
ALTER TABLE analytics.neighborhood_boundaries
ALTER COLUMN geom SET NOT NULL;

-- Import Lisbon neighborhood polygons from GeoJSON

INSERT INTO analytics.neighborhood_boundaries (neighborhood_name, geom)

SELECT
    feature->'properties'->>'neighbourhood' AS neighborhood_name,

    ST_SetSRID(
        ST_Multi(
            ST_CollectionExtract(
                ST_Force2D(
                    ST_MakeValid(
                        ST_GeomFromGeoJSON(feature->>'geometry')
                    )
                ),
                3
            )
        ),
        4326
    ) AS geom

FROM (
    SELECT jsonb_array_elements(data->'features') AS feature
    FROM (
        SELECT pg_read_file(
        '/docker-entrypoint-initdb.d/data/lisbon_neighbourhoods.geojson'
        )::jsonb AS data
    ) f
) sub;

-- View analytics.neighborhood_boundaries Table
SELECT 
    * 
FROM analytics.neighborhood_boundaries
LIMIT 10