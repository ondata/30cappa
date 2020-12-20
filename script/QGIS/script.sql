--
-- the present SQL script is intended to be executed from SpatiaLite_gui
--
-- initializing the output db-file
--
SELECT InitSpatialMetadata(1);

-- crea un db vuoto e importa il vettore Com01012020_g_WGS84 e il CSV comuni
-- in OUTPUT crea un vettore diff_buffer_capol

-- crea vista - buffer da 30km su comuni da 5k
CREATE VIEW v_comuni5k_ab_b30k AS
SELECT c.pro_com_t,c.cod_reg,c.comune,p.Abitanti, st_buffer (geom,30000) as geom  FROM Com01012020_g_WGS84 c 
JOIN (SELECT Abitanti, PRO_COM_T FROM comuni ) p ON c.pro_com_t=p.PRO_COM_T 
WHERE p.Abitanti <=5000;

INSERT INTO views_geometry_columns
(view_name, view_geometry, view_rowid, f_table_name, f_geometry_column, read_only)
VALUES ('v_comuni5k_ab_b30k', 'geom', 'rowid', 'com01012020_g_wgs84', 'geom',1);

-- crea vista - capoluoghi di provincia
CREATE VIEW v_capoluoghi_prov AS
SELECT pro_com_t,cod_rip,cod_reg,comune,geom  
FROM Com01012020_g_WGS84
WHERE cc_uts != 0 ;

INSERT INTO views_geometry_columns
(view_name, view_geometry, view_rowid, f_table_name, f_geometry_column, read_only)
VALUES ('v_capoluoghi_prov', 'geom', 'rowid', 'com01012020_g_wgs84', 'geom',1);

-- clippa i capoluoghi con i buffer da 30km
CREATE TABLE diff_buffer_capol AS
SELECT b.pro_com_t,b.cod_reg,b.comune,CastToMultiPolygon(ST_DIFFERENCE(b.geom , p.geom)) as geom
FROM (SELECT * FROM v_comuni5k_ab_b30k WHERE cod_reg=19)b, (SELECT CastToMultiPolygon(ST_UNION(geom)) AS geom FROM v_capoluoghi_prov WHERE cod_reg=19 ) p
WHERE b.cod_reg = 19 and ST_intersects (b.geom , p.geom) = 1
union
SELECT b.pro_com_t,b.cod_reg,b.comune,CastToMultiPolygon(b.geom) as geom
FROM (SELECT * FROM v_comuni5k_ab_b30k WHERE cod_reg=19)b,(SELECT CastToMultiPolygon(ST_UNION(geom)) AS geom FROM v_capoluoghi_prov WHERE cod_reg=19 ) p
WHERE b.cod_reg = 19 and ST_intersects (b.geom , p.geom) = 0;
SELECT RecoverGeometryColumn('diff_buffer_capol','geom',32632,'MULTIPOLYGON','XY');

-- clippa i buffer comunali con la regione - da rivedere
-- CREATE TABLE inters_buffer_reg AS
-- SELECT b.pro_com_t,b.cod_reg,b.comune,CastToMulti(ST_Intersection(b.geom ,p.geom)) as geom
-- FROM diff_buffer_capol b, (SELECT cod_reg, CastToMultiPolygon(st_union(geom)) as geom FROM Com01012020_g_WGS84 WHERE cod_reg=19 group by cod_reg=19) p
-- WHERE b.cod_reg = 19 and ST_intersects (b.geom , p.geom) = 1;
-- SELECT RecoverGeometryColumn('inters_buffer_reg','geom',32632,'MULTIPOLYGON','XY');


--
-- vacuuming the output db-file
--
VACUUM;