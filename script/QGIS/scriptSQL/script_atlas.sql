--
-- the present SQL script is intended to be executed from SpatiaLite_gui
--
SELECT InitSpatialMetadata(1);
--
-- il vettore Com01012020_g_WGS84 contiene già il campo Abitanti demoistat2020
-- in OUTPUT crea le due tabelle di sotto
--
-- crea tabella - con attributi su tutti i comuni per ogni aree30cappa
CREATE TABLE comune_e_comuni AS
SELECT b.cod_reg,b.cod_prov,b.pro_com_t,b.comune,b.Abitanti AS ABITANTI,
p.cod_reg AS COD_REG_2,p.pro_com_t AS PRO_COM_T_2,p.comune AS COMUNE_2
FROM Com01012020_g_WGS84 b, Aree30cappa p
WHERE ST_intersects (b.geom , p.geom) = 1
AND
b.ROWID IN (
    SELECT ROWID 
    FROM SpatialIndex
    WHERE f_table_name = 'Com01012020_g_WGS84' 
        AND search_frame = p.geom)
AND b.CC_UTS != 1
AND b.comune != p.comune;
--
-- crea geotabella - per ogni aree30cappa lista dei comuni ed altro
CREATE TABLE lista_nro_comuni_x_comune5k AS
SELECT cc."COD_REG_2" AS COD_REG, cc."PRO_COM_T_2" AS PRO_COM_T, cc."COMUNE_2" AS COMUNI,
group_concat(distinct cc."COD_REG_2") AS lista_COD_REG_2, group_concat(cc."PRO_COM_T") AS lista_PRO_COM_T, group_concat(cc."COMUNE") AS lista_comuni,
sum(cc."Abitanti") AS tot_abitanti, count(*) AS nro_comuni, CastToMultiPolygon(ST_UNION (c.geom)) as geom
FROM "comune_e_comuni" cc join "Com01012020_g_WGS84" c USING (PRO_COM_T)
GROUP BY 3;
SELECT RecoverGeometryColumn('lista_nro_comuni_x_comune5k','geom',32632,'MULTIPOLYGON','XY');

--
-- cancella geotabelle inutili
DROP TABLE IF EXISTS comune_e_comuni;
--
-- aggiorno statistiche e VACUUM (nel mio vecchio laptop impiega circa 7 minuti)
--
UPDATE geometry_columns_statistics set last_verified = 0;
SELECT UpdateLayerStatistics('geometry_table_name');
VACUUM;
