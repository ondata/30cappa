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
p.cod_reg AS COD_REG_2,p.cod_prov AS COD_PROV_2,p.pro_com_t AS PRO_COM_T_2,p.comune AS COMUNE_2,p.Abitanti AS ABITANTI_2
FROM Com01012020_g_WGS84 b, Aree30cappa p
WHERE ST_intersects (b.geom , p.geom) = 1
AND
b.ROWID IN (
    SELECT ROWID 
    FROM SpatialIndex
    WHERE f_table_name = 'comuni' 
        AND search_frame = p.geom)
AND b.CC_UTS != 1
AND b.comune != p.comune;
--
-- crea tabella - per ogni aree30cappa lista dei comuni ed altro
CREATE TABLE lista_nro_comuni_x_comune5k AS
SELECT "COD_REG_2", "COD_PROV_2", "PRO_COM_T_2", "COMUNE_2", "Abitanti_2", 
group_concat("COD_REG_2") AS COD_REG_2, group_concat("PRO_COM_T_2") AS PRO_COM_T_2, group_concat("COMUNE") AS lista_comuni,
sum("Abitanti") AS tot_abitanti, count(*) AS nro_comuni
FROM "comune_e_comuni"
GROUP BY 3
ORDER BY nro_comuni desc;
--
-- cancella geotabelle inutili
DROP TABLE IF EXISTS comune_e_comuni;
--
-- aggiorno statistiche e VACUUM (nel mio vecchio laptop impiega circa 7 minuti)
--
UPDATE geometry_columns_statistics set last_verified = 0;
SELECT UpdateLayerStatistics('geometry_table_name');
VACUUM;
