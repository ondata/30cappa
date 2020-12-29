#!/bin/bash

### Nota ###
# Per sapere le ragioni di questo script, leggi qui
# https://medium.com/tantotanto/il-decreto-di-natale-in-chilometri-8af38744a7d5
### Nota ###

### requisiti ###
# gdal/ogr, versione >= 2.4.4 https://gdal.org/
# mapshaper, versione >= 0.5.22 https://github.com/mbloch/mapshaper
# gnu parallel https://www.gnu.org/software/parallel/
# miller https://github.com/johnkerl/miller
# mod_spatialite, versione >= 4.4
### requisiti ###

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# crea cartella per raccogliere dati per sito web
mkdir -p "$folder"/../../dati/arigadicomando/output_noreg

### dati sulla popolazione ###

# rimuovi riga intestazione
tail <"$folder"/../../dati/rawdata/comuni.csv -n +2 >"$folder"/../../dati/arigadicomando/comuni.csv

# estri riga con nomi campo
head <"$folder"/../../dati/arigadicomando/comuni.csv -n 1 >"$folder"/../../dati/arigadicomando/tmp_comuni.csv
# aggiungi corpo, rimuovendo ciò che non inizia per codice comune (in modo da rimuovere footer)
grep <"$folder"/../../dati/arigadicomando/comuni.csv -P '^[0-9]+' >>"$folder"/../../dati/arigadicomando/tmp_comuni.csv

mv "$folder"/../../dati/arigadicomando/tmp_comuni.csv "$folder"/../../dati/arigadicomando/comuni.csv

# crea totale popolazione per codice comunale
mlr -I --csv clean-whitespace \
  then filter -S '${Età}=="999"' \
  then put '$Abitanti=${Totale Maschi}+${Totale Femmine}' \
  then cut -f "Codice comune",Abitanti \
  then rename "Codice comune",PRO_COM_T "$folder"/../../dati/arigadicomando/comuni.csv

# applica zero padding ai codici comunali, da 1001 a 001001
mlr -I --csv put '$PRO_COM_T=fmtnum($PRO_COM_T,"%06d")' "$folder"/../../dati/arigadicomando/comuni.csv

### dati geografici ###

# pulizia topologica di base limiti comunali ISTAT
mapshaper "$folder"/../../dati/rawdata/Limiti01012020_g/Com01012020_g/Com01012020_g_WGS84.shp -clean gap-fill-area=0 -o "$folder"/../../dati/tmp.shp

# JOIN tra limiti comunali e CSV, per aggiungere numero abitanti
mapshaper "$folder"/../../dati/tmp.shp -join "$folder"/../../dati/arigadicomando/comuni.csv keys=PRO_COM_T,PRO_COM_T field-types=PRO_COM_T:str -o "$folder"/../../dati/arigadicomando/comuni.shp

# genera buffer a 30 kilometri dei comuni con meno di 5001 abitanti
ogr2ogr -t_srs EPSG:4326 "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp "$folder"/../../dati/arigadicomando/comuni.shp -dialect sqlite -sql "SELECT PRO_COM_T,COD_REG,COMUNE,Abitanti,ST_MakeValid(st_buffer(comuni.geometry,30000)) AS geom FROM comuni where Abitanti <= 5000"

# estrai capoluoghi di provincia dai limiti comunali ISTAT
mapshaper-xl "$folder"/../../dati/arigadicomando/comuni.shp -filter 'CC_UTS==1' -filter-fields PRO_COM_T,COD_REG,COMUNE,Abitanti -proj wgs84 -o "$folder"/../../dati/arigadicomando/capoluoghi_4326.shp

# crea poligono stato Italia a partire dai limiti comunali
mapshaper-xl "$folder"/../../dati/arigadicomando/comuni.shp -dissolve -proj wgs84 -o precision=0.000001 "$folder"/../../dati/arigadicomando/italia.shp

# ritaglia i buffer dei comuni con il limite dell'italia
mapshaper-xl "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp -clip "$folder"/../../dati/arigadicomando/italia.shp -explode -o "$folder"/../../dati/arigadicomando/tmp.shp

# rimuovi db sqlite se esiste
db="$folder/../../dati/arigadicomando/db.sqlite"
if [ -f "$db" ]; then
  rm "$db"
fi

# importa in sqlite i buffer dei comuni
ogr2ogr -f SQLite -dsco SPATIALITE=YES "$folder"/../../dati/arigadicomando/db.sqlite "$folder"/../../dati/arigadicomando/tmp.shp -nln a -lco SPATIAL_INDEX=YES -nlt PROMOTE_TO_MULTI

# importa in sqlite i limiti dei comuni capoluogo
ogr2ogr -append -f SQLite -dsco SPATIALITE=YES "$folder"/../../dati/arigadicomando/db.sqlite "$folder"/../../dati/arigadicomando/capoluoghi_4326.shp -nln b -lco SPATIAL_INDEX=YES -nlt PROMOTE_TO_MULTI

# correggi eventuali problemi geometrici del layer dei buffer
ogrinfo "$folder"/../../dati/arigadicomando/db.sqlite -sql 'UPDATE a SET GEOMETRY = MakeValid(GEOMETRY) WHERE ST_IsValid(GEOMETRY) <> 1;'

# fai intersezione tra buffer e capoluoghi
ogrinfo "$folder"/../../dati/arigadicomando/db.sqlite -sql "SELECT ST_Cutter(NULL, 'a', NULL, NULL, 'b', NULL, 'out', 1, 1);"

#echo "SELECT ST_Cutter(NULL, 'a', NULL, NULL, 'b', NULL, 'out', 1, 1);" | sqlite3 $db

# crea tabella dei buffer senza aree corrispondenti ai capoluoghi
ogrinfo "$folder"/../../dati/arigadicomando/db.sqlite -sql 'create table buffer_clipped AS
SELECT PRO_COM_T, COMUNE, geometry
FROM
(SELECT "input_a_ogc_fid", "blade_b_ogc_fid", a.pro_com_t PRO_COM_T, a.comune COMUNE, out."geometry"
FROM
"out"
LEFT JOIN a ON out.input_a_ogc_fid = a.ogc_fid
WHERE
"blade_b_ogc_fid" IS NULL);'

# fai diventare spaziale/geografica la tabella creata
ogrinfo "$folder"/../../dati/arigadicomando/db.sqlite -sql "SELECT RecoverGeometryColumn('buffer_clipped','geometry',4326,'POLYGON','XY');"

# esporta layer dei buffer
ogr2ogr "$folder"/../../dati/arigadicomando/tmp_buffer.shp "$folder"/../../dati/arigadicomando/db.sqlite buffer_clipped

# dissolvi layer per codice ISTAT
mapshaper-xl "$folder"/../../dati/arigadicomando/tmp_buffer.shp -dissolve PRO_COM_T copy-fields=COMUNE -o precision=0.000001 "$folder"/../../dati/arigadicomando/buffer.shp

# estrai un geojson per ogni comune
mapshaper-xl "$folder"/../../dati/arigadicomando/buffer.shp -split PRO_COM_T -o format=geojson "$folder"/../../dati/arigadicomando/output_noreg/
