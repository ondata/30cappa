--
-- the present SQL script is intended to be executed from SpatiaLite_gui
--
SELECT InitSpatialMetadata(1);
--
-- il vettore Com01012020_g_WGS84 contiene già il campo Abitanti demoistat2020
-- in OUTPUT crea un vettore aree30cappa
--
-- crea tabella - buffer da 30km su comuni da 5k
SELECT DropGeoTable( "b30k_comuni5k");
CREATE TABLE b30k_comuni5k AS
SELECT pro_com_t,cod_reg,comune,Abitanti, st_buffer (geom,30000) as geom  
FROM Com01012020_g_WGS84 
WHERE abitanti <=5000;
SELECT RecoverGeometryColumn('b30k_comuni5k','geom',32632,'POLYGON','XY');
SELECT CreateSpatialIndex('b30k_comuni5k', 'geom');
--
-- crea tabella - capoluoghi di provincia
SELECT DropGeoTable( "capoluoghi_prov");
CREATE TABLE capoluoghi_prov AS
SELECT pro_com_t,cod_rip,cod_reg,comune,geom  
FROM Com01012020_g_WGS84
WHERE cc_uts != 0;
SELECT RecoverGeometryColumn('capoluoghi_prov','geom',32632,'MULTIPOLYGON','XY');
SELECT CreateSpatialIndex('capoluoghi_prov', 'geom');
--
-- crea tabella temporanea unendo i capoluoghi di provincia
SELECT DropGeoTable( "tmp_cap_prov");
CREATE TABLE tmp_cap_prov AS
SELECT CastToMultiPolygon(ST_UNION(geom)) AS geom FROM capoluoghi_prov;
SELECT RecoverGeometryColumn('tmp_cap_prov','geom',32632,'MULTIPOLYGON','XY');
--
-- crea tabella temporanea unendo tutti i comuni
SELECT DropGeoTable( "tmp_italia");
CREATE TABLE tmp_italia AS
SELECT CastToMultiPolygon(ST_UNION(geom)) AS geom FROM Com01012020_g_WGS84;
SELECT RecoverGeometryColumn('tmp_italia','geom',32632,'MULTIPOLYGON','XY');
--
-- clippa italia con i buffer da 30km e comuni 5k
SELECT DropGeoTable( "b30k_comuni5k_italia");
CREATE TABLE b30k_comuni5k_italia AS
SELECT b.pro_com_t,b.cod_reg,b.comune,CastToMultiPolygon(ST_Intersection(b.geom ,p.geom)) as geom
FROM b30k_comuni5k b, tmp_italia p
WHERE ST_intersects (b.geom , p.geom) = 1;
SELECT RecoverGeometryColumn('b30k_comuni5k_italia','geom',32632,'MULTIPOLYGON','XY');
--
-- clippa i capoluoghi con i buffer da 30km e comuni 5k clippati con italia
SELECT DropGeoTable( "aree30cappa");
CREATE TABLE aree30cappa AS
SELECT b.pro_com_t,b.cod_reg,b.comune,CastToMultiPolygon(ST_DIFFERENCE(b.geom , p.geom)) as geom
FROM b30k_comuni5k_italia b, tmp_cap_prov p
WHERE ST_intersects (b.geom , p.geom) = 1
union
SELECT b.pro_com_t,b.cod_reg,b.comune,CastToMultiPolygon(b.geom) as geom
FROM b30k_comuni5k_italia b,tmp_cap_prov p
WHERE ST_intersects (b.geom , p.geom) = 0;
SELECT RecoverGeometryColumn('aree30cappa','geom',32632,'MULTIPOLYGON','XY');
SELECT CreateSpatialIndex('aree30cappa', 'geom');
--
-- cancella geotabelle inutili
DROP TABLE IF EXISTS tmp_cap_prov;
DROP TABLE IF EXISTS tmp_italia;
DROP TABLE IF EXISTS b30k_comuni5k;
DROP TABLE IF EXISTS capoluoghi_prov;
DROP TABLE IF EXISTS tmp_cap_prov;
DROP TABLE IF EXISTS tmp_italia;
DROP TABLE IF EXISTS b30k_comuni5k_italia;
--
-- aggiorno statistiche e VACUUM (nel mio vecchio laptop impiega circa 7 minuti)
--
UPDATE geometry_columns_statistics set last_verified = 0;
SELECT UpdateLayerStatistics('geometry_table_name');
VACUUM;
