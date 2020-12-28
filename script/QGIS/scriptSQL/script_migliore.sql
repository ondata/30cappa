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
CREATE TABLE "b30k_comuni5k"
      ("pk_id" integer PRIMARY KEY autoincrement NOT NULL,
       "pro_com_t" text,"cod_rip" INTEGER,"cod_reg" text,"comune" text,"abitanti" INTEGER );
-- aggiunge campo geom
SELECT AddGeometryColumn ('b30k_comuni5k','geom',32632,'MULTIPOLYGON','XY');
--
INSERT INTO "b30k_comuni5k"
(pk_id, pro_com_t,cod_rip,cod_reg,comune,abitanti, geom)
SELECT NULL, pro_com_t,cod_rip,cod_reg,comune,abitanti, CastToMultiPolygon(ST_Buffer (geom,30000)) AS geom
FROM (SELECT NULL,pro_com_t,cod_rip,cod_reg,comune,abitanti, geom 
      FROM Com01012020_g_WGS84
      WHERE abitanti <=5000);
--
SELECT CreateSpatialIndex('b30k_comuni5k', 'geom');
--
-- crea tabella - capoluoghi di provincia
SELECT DropGeoTable( "capoluoghi_prov");
CREATE TABLE "capoluoghi_prov" 
      ("pk_id" integer PRIMARY KEY autoincrement NOT NULL,
       "pro_com_t" text,"cod_rip" INTEGER,"cod_reg" text,"comune" text,"abitanti" INTEGER );
-- aggiunge campo geom
SELECT AddGeometryColumn ('capoluoghi_prov','geom',32632,'MULTIPOLYGON','XY');
-- popola la tabella
INSERT INTO "capoluoghi_prov"
(pk_id, pro_com_t,cod_rip,cod_reg,comune,abitanti, geom)
SELECT NULL, pro_com_t,cod_rip,cod_reg,comune,abitanti, geom
FROM (SELECT NULL,pro_com_t,cod_rip,cod_reg,comune,abitanti,geom  
      FROM Com01012020_g_WGS84
      WHERE cc_uts != 0);
--
-- crea tabella temporanea unendo tutti i comuni
SELECT DropGeoTable( "tmp_italia");
CREATE TABLE "tmp_italia" 
      ("pk_id" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('tmp_italia','geom',32632,'MULTIPOLYGON','XY');
-- popola la tabella
INSERT INTO "tmp_italia" VALUES (1,NULL);
-- aggiorna tabella
UPDATE "tmp_italia" SET geom = 
(SELECT CastToMultiPolygon(ST_UNION(geom)) AS geom FROM "Com01012020_g_WGS84") WHERE  pk_id = 1;
--
SELECT DropGeoTable( "italia_subd2048");
CREATE TABLE "italia_subd2048" AS
SELECT ST_Subdivide(geom,2048) AS geom FROM "tmp_italia";
SELECT RecoverGeometryColumn('italia_subd2048','geom',32632,'MULTIPOLYGON','XY');
--
SELECT ElementaryGeometries( 'italia_subd2048',
                             'geom',
                             'italia_subd2048_elem',
                             'pk_elem',
                             'out_multi_id', 1 ) as num;
--
-- SELECT ST_Cutter(NULL, 'italia_subd2048_elem', NULL, NULL, 'b30k_comuni5k', NULL, 'b30k_com5k_italy_subd_elem', 1, 1);
SELECT ST_Cutter(NULL, 'b30k_comuni5k', NULL, NULL, 'italia_subd2048_elem', NULL, 'b30k_com5k_italy_subd_elem', 1, 1);
--
SELECT DropGeoTable( "b30k_com5k_italy");
CREATE TABLE "b30k_com5k_italy" 
      ("pk_uid" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('b30k_com5k_italy','geom',32632,'MULTIPOLYGON','XY');
INSERT INTO "b30k_com5k_italy" 
(pk_uid,geom)
SELECT NULL, k.geom
FROM (SELECT "input_b30k_comuni5k_pk_id", "blade_italia_subd2048_elem_pk_elem", CastToMultiPolygon(st_union("geom")) AS geom
FROM "b30k_com5k_italy_subd_elem"
where "blade_italia_subd2048_elem_pk_elem" is not null
group by "input_b30k_comuni5k_pk_id") k;
SELECT RecoverGeometryColumn('b30k_com5k_italy','geom',32632,'MULTIPOLYGON','XY');
--
SELECT ST_Cutter(NULL, 'b30k_com5k_italy', NULL, NULL, 'capoluoghi_prov', NULL, 'b30k_com5k_italy_subd_elem_capolp', 1, 1);
-- SELECT ST_Cutter(NULL, 'capoluoghi_prov', NULL, NULL, 'b30k_com5k_italy', NULL, 'b30k_com5k_italy_subd_elem_capolp2', 1, 1);
--
SELECT DropGeoTable( "finale");
CREATE TABLE "finale" 
      ("pk_uid" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('finale','geom',32632,'MULTIPOLYGON','XY');
INSERT INTO "finale" 
(pk_uid,geom)
SELECT NULL, k.geom
FROM (SELECT "input_b30k_com5k_italy_pk_uid", CastToMultiPolygon(st_union("geom")) AS geom
      FROM "b30k_com5k_italy_subd_elem_capolp"
      WHERE "blade_capoluoghi_prov_pk_id" is null
      group by "input_b30k_com5k_italy_pk_uid") k;
SELECT RecoverGeometryColumn('finale','geom',32632,'MULTIPOLYGON','XY');
--
-- aggiorno statistiche e VACUUM (nel mio vecchio laptop impiega circa 7 minuti)
--
UPDATE geometry_columns_statistics set last_verified = 0;
SELECT UpdateLayerStatistics('geometry_table_name');
VACUUM;
