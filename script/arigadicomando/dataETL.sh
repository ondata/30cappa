#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/../../dati
mkdir -p "$folder"/../../dati/arigadicomando
mkdir -p "$folder"/../../dati/arigadicomando/output
mkdir -p "$folder"/../../dati/arigadicomando/risorse

### dati sulla popolazione ###

# rimuovi riga intestazione
tail <"$folder"/../../dati/rawdata/comuni.csv -n +2 >"$folder"/../../dati/arigadicomando/comuni.csv

# crea totale popolazione per codice comunale
mlr -I --csv clean-whitespace \
  then filter -S '${Età}=="999"' \
  then put '$Abitanti=${Totale Maschi}+${Totale Femmine}' \
  then cut -f "Codice comune",Abitanti \
  then rename "Codice comune",PRO_COM_T "$folder"/../../dati/arigadicomando/comuni.csv

# applica zero padding ai codici comunali, da 1001 a 001001
mlr -I --csv put '$PRO_COM_T=fmtnum($PRO_COM_T,"%06d")' "$folder"/../../dati/arigadicomando/comuni.csv

### dati geografici ###

# pulizia topologica di base
mapshaper "$folder"/../../dati/rawdata/Limiti01012020_g/Com01012020_g/Com01012020_g_WGS84.shp -clean gap-fill-area=0 -o "$folder"/../../dati/tmp.shp

# JOIN con CSV per abitanti
mapshaper "$folder"/../../dati/tmp.shp -join "$folder"/../../dati/comuni.csv keys=PRO_COM_T,PRO_COM_T field-types=PRO_COM_T:str -o "$folder"/../../dati/arigadicomando/comuni.shp

# genera buffer a 30 kilometri dei comuni con meno di 5001 abitanti
ogr2ogr -t_srs EPSG:4326 "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp "$folder"/../../dati/arigadicomando/comuni.shp -dialect sqlite -sql "SELECT PRO_COM_T,COD_REG,COMUNE,Abitanti,st_buffer(comuni.geometry,30000) AS geom FROM comuni where Abitanti <= 5000"

# estrarre capoluoghi di provincia
mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -filter 'CC_UTS==1' -filter-fields PRO_COM_T,COD_REG,COMUNE,Abitanti -proj wgs84 -o "$folder"/../../dati/arigadicomando/capoluoghi_4326.shp

# crea Italia
mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -dissolve -proj wgs84 -o precision=0.000001 "$folder"/../../dati/arigadicomando/italia.shp

# ritagliare i buffer dei comuni con il limite dell'italia
mapshaper "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp -clip "$folder"/../../dati/arigadicomando/italia.shp -o "$folder"/../../dati/arigadicomando/tmp.shp

# crea CSV di servizio
ogr2ogr -f CSV "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.CSV "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp
mlr -I --csv clean-whitespace "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.CSV

# crea lista codici comuni
mlr --c2t cut -f PRO_COM_T,COD_REG "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.CSV | tail -n +2 >"$folder"/../../dati/arigadicomando/lista.tsv

## estrai un geojson per ogni comune
rm "$folder"/../../dati/arigadicomando/output_noreg/*json
mapshaper "$folder"/../../dati/arigadicomando/tmp.shp -split PRO_COM_T -o format=geojson "$folder"/../../dati/arigadicomando/output_noreg/

# rimuovi dai "poligoni buffer comune" area dei capoluoghi
parallel --colsep "\t" -j100% 'mapshaper ../../dati/arigadicomando/output_noreg/{1}.json -erase ../../dati/arigadicomando/capoluoghi_4326.shp -o precision=0.000001 ../../dati/arigadicomando/output_noreg/{1}.geojson' :::: ./../../dati/arigadicomando/lista.tsv


