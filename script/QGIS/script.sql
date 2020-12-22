--
-- the present SQL script is intended to be executed from SpatiaLite_gui
--
-- initializing the output db-file
--
SELECT InitSpatialMetadata(1);

-- crea un db vuoto e importa il vettore Com01012020_g_WGS84 e il CSV comuni
-- in OUTPUT crea un vettore diff_buffer_capol

-- crea tabella - buffer da 30km su comuni da 5k
CREATE TABLE comuni5k_ab_b30k AS
SELECT c.pro_com_t,c.cod_reg,c.comune,p.Abitanti, st_buffer (geom,30000) as geom  FROM Com01012020_g_WGS84 c 
JOIN (SELECT Abitanti, PRO_COM_T FROM comuni ) p ON c.pro_com_t=p.PRO_COM_T 
WHERE p.Abitanti <=5000;
SELECT RecoverGeometryColumn('comuni5k_ab_b30k','geom',32632,'POLYGON','XY');
SELECT CreateSpatialIndex('comuni5k_ab_b30k', 'geom');

-- crea vista - capoluoghi di provincia
CREATE TABLE capoluoghi_prov AS
SELECT pro_com_t,cod_rip,cod_reg,comune,geom  
FROM Com01012020_g_WGS84
WHERE cc_uts != 0;
SELECT RecoverGeometryColumn('capoluoghi_prov','geom',32632,'MULTIPOLYGON','XY');
SELECT CreateSpatialIndex('capoluoghi_prov', 'geom');

CREATE TABLE tmp_cap_prov AS
SELECT CastToMultiPolygon(ST_UNION(geom)) AS geom FROM capoluoghi_prov;
SELECT RecoverGeometryColumn('tmp_cap_prov','geom',32632,'MULTIPOLYGON','XY');


-- clippa i capoluoghi con i buffer da 30km - cod_reg=19 Sicilia
CREATE TABLE diff_buffer_capoluoghi AS
SELECT b.pro_com_t,b.cod_reg,b.comune,CastToMultiPolygon(ST_DIFFERENCE(b.geom , p.geom)) as geom
FROM (SELECT * FROM comuni5k_ab_b30k)b, tmp_cap_prov p
WHERE ST_intersects (b.geom , p.geom) = 1
union
SELECT b.pro_com_t,b.cod_reg,b.comune,CastToMultiPolygon(b.geom) as geom
FROM (SELECT * FROM comuni5k_ab_b30k)b,tmp_cap_prov p
WHERE ST_intersects (b.geom , p.geom) = 0;
SELECT RecoverGeometryColumn('diff_buffer_capoluoghi','geom',32632,'MULTIPOLYGON','XY');
SELECT CreateSpatialIndex('diff_buffer_capoluoghi', 'geom');

-- clippa i buffer comunali con la regione - da rivedere
CREATE TABLE aree30cappa AS
SELECT b.pro_com_t,b.cod_reg,p.cod_reg AS cod_reg_2,b.comune,CastToMultiPolygon(ST_Intersection(b.geom ,p.geom)) as geom
FROM diff_buffer_capoluoghi b, tmp_regioni p
WHERE ST_intersects (b.geom , p.geom) = 1
AND
b.ROWID IN (
    SELECT ROWID 
    FROM SpatialIndex
    WHERE f_table_name = 'diff_buffer_capoluoghi' 
        AND search_frame = p.geom)
AND COD_REG = COD_REG_2;
SELECT RecoverGeometryColumn('aree30cappa','geom',32632,'MULTIPOLYGON','XY');


--
-- vacuuming the output db-file
--
VACUUM;