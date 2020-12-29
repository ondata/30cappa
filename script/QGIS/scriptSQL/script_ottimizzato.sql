--
-- the present SQL script is intended to be executed from SpatiaLite_gui
--
SELECT InitSpatialMetadata(1);
--
-- il vettore Com01012020_g_WGS84 contiene già il campo Abitanti demoistat2020
-- in OUTPUT crea un vettore aree30cappa
--
-- crea tabella - buffer da 30 km su comuni da 5k
SELECT DropGeoTable( "b30k_comuni5k");
CREATE TABLE "b30k_comuni5k"
      ("pk_uid" integer PRIMARY KEY autoincrement NOT NULL,
       "pro_com_t" text);
-- aggiunge campo geom
SELECT AddGeometryColumn ('b30k_comuni5k','geom',32632,'MULTIPOLYGON','XY');
--
INSERT INTO "b30k_comuni5k"
(pk_uid, pro_com_t, geom)
SELECT pk_uid, pro_com_t, CastToMultiPolygon(ST_Buffer (geom,30000)) AS geom
FROM (SELECT pk_uid,pro_com_t, geom 
      FROM "Com01012020_g_WGS84"
      WHERE abitanti <=5000);
--
SELECT CreateSpatialIndex('b30k_comuni5k', 'geom');
--
-- crea tabella - capoluoghi di provincia
SELECT DropGeoTable( "capoluoghi_prov");
CREATE TABLE "capoluoghi_prov" 
      ("pk_uid" integer PRIMARY KEY autoincrement NOT NULL,
       "pro_com_t" text);
-- aggiunge campo geom
SELECT AddGeometryColumn ('capoluoghi_prov','geom',32632,'MULTIPOLYGON','XY');
-- popola la tabella
INSERT INTO "capoluoghi_prov"
(pk_uid, pro_com_t, geom)
SELECT pk_uid, pro_com_t, geom
FROM (SELECT pk_uid,pro_com_t,geom  
      FROM Com01012020_g_WGS84
      WHERE cc_uts != 0);
--
-- crea tabella temporanea unendo tutti i comuni
SELECT DropGeoTable( "tmp_italia");
CREATE TABLE "tmp_italia" 
      ("pk_uid" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('tmp_italia','geom',32632,'MULTIPOLYGON','XY');
-- popola la tabella
INSERT INTO "tmp_italia" VALUES (1,NULL);
-- aggiorna tabella
UPDATE "tmp_italia" SET geom = 
(SELECT CastToMultiPolygon(ST_UNION(geom)) AS geom FROM "Com01012020_g_WGS84") WHERE  pk_uid = 1;
--
-- suddivide l'intero poligono nazionale
SELECT DropGeoTable( "italia_subd2048");
CREATE TABLE "italia_subd2048" AS
SELECT ST_Subdivide(geom,2048) AS geom FROM "tmp_italia";
SELECT RecoverGeometryColumn('italia_subd2048','geom',32632,'MULTIPOLYGON','XY');
--
-- estrae i poligoni elementari
SELECT ElementaryGeometries( 'italia_subd2048',
                             'geom',
                             'italia_subd2048_elem',
                             'pk_elem',
                             'out_multi_id', 1 ) as num;
--
-- taglia i buffer secondo il vettore dato
SELECT ST_Cutter(NULL, 'b30k_comuni5k', NULL, NULL, 'italia_subd2048_elem', NULL, 'b30k_com5k_italy_subd_elem', 1, 1);
--
-- ricompone i pezzi - ricorda che pk_id si riferisce alla tabella comuni 'Com01012020_g_WGS84'
SELECT DropGeoTable( "b30k_com5k_italy");
CREATE TABLE "b30k_com5k_italy" 
      ("pk_uid" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('b30k_com5k_italy','geom',32632,'MULTIPOLYGON','XY');
INSERT INTO "b30k_com5k_italy" 
(pk_uid,geom)
SELECT k."input_b30k_comuni5k_pk_uid" AS pk_uid, k.geom
FROM (SELECT "input_b30k_comuni5k_pk_uid", "blade_italia_subd2048_elem_pk_elem", CastToMultiPolygon(st_union("geom")) AS geom
      FROM "b30k_com5k_italy_subd_elem"
      WHERE "blade_italia_subd2048_elem_pk_elem" is NOT NULL
      GROUP BY "input_b30k_comuni5k_pk_uid") k;
SELECT RecoverGeometryColumn('b30k_com5k_italy','geom',32632,'MULTIPOLYGON','XY');
--
-- taglia i buffer sagomati con lo stivale secondo il vettore dei capoluoghi
SELECT ST_Cutter(NULL, 'b30k_com5k_italy', NULL, NULL, 'capoluoghi_prov', NULL, 'b30k_com5k_italy_subd_elem_capolp', 1, 1);
--
-- ricompone i pezzi - ricorda che pk_uid si riferisce alla tabella comuni 'Com01012020_g_WGS84'
SELECT DropGeoTable( "finale");
CREATE TABLE "finale" 
      ("pk_uid" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('finale','geom',32632,'MULTIPOLYGON','XY');
INSERT INTO "finale" 
(pk_uid,geom)
SELECT k."input_b30k_com5k_italy_pk_uid" AS pk_uid, k.geom
FROM (SELECT "input_b30k_com5k_italy_pk_uid", CastToMultiPolygon(st_union("geom")) AS geom
      FROM "b30k_com5k_italy_subd_elem_capolp"
      WHERE "blade_capoluoghi_prov_pk_uid" is null
      group by "input_b30k_com5k_italy_pk_uid") k;
SELECT RecoverGeometryColumn('finale','geom',32632,'MULTIPOLYGON','XY');
--
-- associa campo pro_com_t ed altri
SELECT DropGeoTable( "aree30cappa");
CREATE TABLE "aree30cappa" AS
SELECT f."pk_uid",c."pro_com_t",c."cod_reg",c."comune",c."abitanti",f."geom"
FROM "finale" f left join "Com01012020_g_WGS84" c USING ("pk_uid");
SELECT RecoverGeometryColumn('aree30cappa','geom',32632,'MULTIPOLYGON','XY');
--
-- cancella geotabelle inutili
DROP TABLE IF EXISTS "b30k_comuni5k";
DROP TABLE IF EXISTS "capoluoghi_prov";
DROP TABLE IF EXISTS "tmp_italia";
DROP TABLE IF EXISTS "italia_subd2048";
DROP TABLE IF EXISTS "italia_subd2048_elem";
DROP TABLE IF EXISTS "b30k_com5k_italy_subd_elem";
DROP TABLE IF EXISTS "b30k_com5k_italy";
DROP TABLE IF EXISTS "b30k_com5k_italy_subd_elem_capolp";
DROP TABLE IF EXISTS "finale";
--
-- aggiorno statistiche e VACUUM (nel mio vecchio laptop impiega circa 4 minuti)
--
SELECT UpdateLayerStatistics('aree30cappa');
VACUUM;
