
## Il decreto "di Natale" sugli spostamenti piccoli comuni

Come ho risolto il #30cappa del decreto "di Natale".

## Software usati

Ho usato solo SpatiaLite 5.0 e le sue incredibile funzioni spaziali. Per la visualizzazione ho usato QGIS 3.16 Hannover

## Parto dai limiti amministrativi comunali

shapefile ISTAT al 01/01/2020

<img src = "./imgs/img_01.png" width =600>

## Creo Buffer di 30 km

sui comuni con popolazione <= 5.000
```sql
-- crea tabella - buffer da 30 km su comuni da 5k
DROP TABLE IF EXISTS "b30k_comuni5k";
CREATE TABLE "b30k_comuni5k"
      ("pk_uid" integer PRIMARY KEY autoincrement NOT NULL,"pro_com_t" text);
-- aggiunge campo geom
SELECT AddGeometryColumn ('b30k_comuni5k','geom',32632,'MULTIPOLYGON','XY');
-- popola la tabella con abitanti minori di 5001
INSERT INTO "b30k_comuni5k"
(pk_uid, pro_com_t, geom)
SELECT pk_uid, pro_com_t, CastToMultiPolygon(ST_Buffer (geom,30000)) AS geom
FROM (SELECT pk_uid,pro_com_t, geom 
      FROM "Com01012020_g_WGS84"
      WHERE abitanti <=5000);
```

<img src = "./imgs/img_02.png" width =600>

## Estraggo i soli capoluoghi di provincia

serviranno successivamente per bucare i buffer da 30 km
```sql
-- crea tabella - capoluoghi di provincia
DROP TABLE IF EXISTS "capoluoghi_prov";
CREATE TABLE "capoluoghi_prov" 
      ("pk_uid" integer PRIMARY KEY autoincrement NOT NULL,"pro_com_t" text);
-- aggiunge campo geom
SELECT AddGeometryColumn ('capoluoghi_prov','geom',32632,'MULTIPOLYGON','XY');
-- popola la tabella
INSERT INTO "capoluoghi_prov"
(pk_uid, pro_com_t, geom)
SELECT pk_uid, pro_com_t, geom
FROM (SELECT pk_uid,pro_com_t,geom  
      FROM Com01012020_g_WGS84
      WHERE cc_uts != 0);
```

<img src = "./imgs/img_03.png" width =600>

## Unisco tutti i comuni

servirà successivamente per sagomare i buffer con lo stivale
```sql
-- crea tabella temporanea unendo tutti i comuni
DROP TABLE IF EXISTS "tmp_italia";
CREATE TABLE "tmp_italia" 
      ("pk_uid" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('tmp_italia','geom',32632,'MULTIPOLYGON','XY');
-- popola la tabella
INSERT INTO "tmp_italia" VALUES (1,NULL);
-- aggiorna tabella
UPDATE "tmp_italia" SET geom = 
      (SELECT CastToMultiPolygon(ST_UNION(geom)) AS geom
       FROM "Com01012020_g_WGS84") 
       WHERE  pk_uid = 1;
```

<img src = "./imgs/img_04.png" width =600>

## Suddivito lo stivale
la suddivisione evita lunghi tempi di analisi (vale per grandi poligoni)

```sql
-- suddivide l'intero poligono nazionale
DROP TABLE IF EXISTS "italia_subd";
CREATE TABLE "italia_subd" AS
SELECT ST_Subdivide(geom,2048) AS geom FROM "tmp_italia";
SELECT RecoverGeometryColumn('italia_subd','geom',32632,'MULTIPOLYGON','XY');
```

<img src = "./imgs/img_05.png" width =600>

## Estraggo le parti elementari

la suddivisione crea unica feature

```sql
-- estrae i poligoni elementari del poligono nazionale
SELECT ElementaryGeometries( 'italia_subd',
                             'geom',
                             'italia_subd_elem',
                             'pk_elem',
                             'out_multi_id', 1 ) as num;
```

<img src = "./imgs/img_06.png" width =600>

##  Taglio i buffer da 30 km 

con l'Italia suddivisa a pezzi

```sql
-- taglia i buffer secondo il vettore dato
SELECT ST_Cutter(NULL, 'b30k_comuni5k', NULL, NULL, 'italia_subd_elem', NULL, 'b30k_com5k_italy_subd_elem', 1, 1);
```

<img src = "./imgs/img_07.png" width =600>

## Ricompongo i pezzi

fondo i buffer da 30 km tagliati in precedenza

```sql
-- ricompone i pezzi - ricorda che pk_uid si riferisce alla tabella comuni 'Com01012020_g_WGS84'
DROP TABLE IF EXISTS "b30k_com5k_italy";
CREATE TABLE "b30k_com5k_italy" 
      ("pk_uid" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('b30k_com5k_italy','geom',32632,'MULTIPOLYGON','XY');
INSERT INTO "b30k_com5k_italy" 
(pk_uid,geom)
SELECT k."input_b30k_comuni5k_pk_uid" AS pk_uid, k.geom
FROM (SELECT "input_b30k_comuni5k_pk_uid", "blade_italia_subd_elem_pk_elem", CastToMultiPolygon(st_union("geom")) AS geom
      FROM "b30k_com5k_italy_subd_elem"
      WHERE "blade_italia_subd_elem_pk_elem" is NOT NULL
      GROUP BY "input_b30k_comuni5k_pk_uid") k;
SELECT RecoverGeometryColumn('b30k_com5k_italy','geom',32632,'MULTIPOLYGON','XY');
```

<img src = "./imgs/img_08.png" width =600>

## Buco i buffer

dai buffer 30 km sagomati, taglio i capoluoghi di provincia

```sql
-- taglia i buffer sagomati con lo stivale secondo il vettore dei capoluoghi
SELECT ST_Cutter(NULL, 'b30k_com5k_italy', NULL, NULL, 'capoluoghi_prov', NULL, 'b30k_com5k_italy_subd_elem_capolp', 1, 1);
```

<img src = "./imgs/img_09.png" width =600>

## Ricompongo i pezzi

fondo i buffer da 30 km tagliati in precedenza

```sql
-- ricompone i pezzi - ricorda che pk_uid si riferisce alla tabella comuni 'Com01012020_g_WGS84'
DROP TABLE IF EXISTS "finale";
CREATE TABLE "finale" 
      ("pk_uid" INTEGER PRIMARY KEY);
-- aggiunge campo geom
SELECT AddGeometryColumn ('finale','geom',32632,'MULTIPOLYGON','XY');
INSERT INTO "finale" 
(pk_uid,geom)
SELECT k."input_b30k_com5k_italy_pk_uid" AS pk_uid, k.geom
FROM (SELECT "input_b30k_com5k_italy_pk_uid", CastToMultiPolygon(st_union("geom")) AS geom
      FROM "b30k_com5k_italy_subd_elem_capolp"
      WHERE "blade_capoluoghi_prov_pk_uid" IS NULL AND ST_Area(geom) > 1
      group by "input_b30k_com5k_italy_pk_uid") k;
SELECT RecoverGeometryColumn('finale','geom',32632,'MULTIPOLYGON','XY');
```

<img src = "./imgs/img_10.png" width =600>

## Associo i dati necessari

ricostruisco la tabella con i dati necessari

```sql
-- associa campo pro_com_t ed altri
DROP TABLE IF EXISTS "aree30cappa";
CREATE TABLE "aree30cappa" AS
SELECT f."pk_uid",c."pro_com_t",c."cod_reg",c."comune",c."abitanti",f."geom"
FROM "finale" f left join "Com01012020_g_WGS84" c USING ("pk_uid");
SELECT RecoverGeometryColumn('aree30cappa','geom',32632,'MULTIPOLYGON','XY');
```

<img src = "./imgs/img_11.png" width =600>


## Cancello le tabelle inutili

il processo necessita di tabelle intermedie

```sql
-- cancella geotabelle inutili
DROP TABLE IF EXISTS "b30k_comuni5k";
DROP TABLE IF EXISTS "capoluoghi_prov";
DROP TABLE IF EXISTS "tmp_italia";
DROP TABLE IF EXISTS "italia_subd";
DROP TABLE IF EXISTS "italia_subd_elem";
DROP TABLE IF EXISTS "b30k_com5k_italy_subd_elem";
DROP TABLE IF EXISTS "b30k_com5k_italy";
DROP TABLE IF EXISTS "b30k_com5k_italy_subd_elem_capolp";
DROP TABLE IF EXISTS "finale";
--
-- aggiorno statistiche e VACUUM (nel mio vecchio laptop impiega circa 4 minuti)
--
SELECT UpdateLayerStatistics('aree30cappa');
VACUUM;
```