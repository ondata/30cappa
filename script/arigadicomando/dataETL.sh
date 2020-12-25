#!/bin/bash

### Nota ###
# Per sapere le ragioni di questo script, leggi qui
# https://medium.com/tantotanto/il-decreto-di-natale-in-chilometri-8af38744a7d5
### Nota ###

### requisiti ###
# gdal/ogr https://gdal.org/
# mapshaper https://github.com/mbloch/mapshaper
# gnu parallel https://www.gnu.org/software/parallel/
# miller https://github.com/johnkerl/miller
### requisiti ###

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# crea cartella per raccogliere dati per sito web
mkdir -p "$folder"/../../adati/arigadicomando/output_noreg

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

# estrai capoluoghi di provincia
mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -filter 'CC_UTS==1' -filter-fields PRO_COM_T,COD_REG,COMUNE,Abitanti -proj wgs84 -o "$folder"/../../dati/arigadicomando/capoluoghi_4326.shp

# crea poligono stato Italia
mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -dissolve -proj wgs84 -o precision=0.000001 "$folder"/../../dati/arigadicomando/italia.shp

# ritagliare i buffer dei comuni con il limite dell'italia
mapshaper "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp -clip "$folder"/../../dati/arigadicomando/italia.shp -o "$folder"/../../dati/arigadicomando/tmp.shp

### dati per pagina web ###

# crea lista codici comuni
ogr2ogr -f CSV /vsistdout/ "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp |
  mlr --c2t clean-whitespace then cut -f PRO_COM_T,COD_REG |
  tail -n +2 >"$folder"/../../dati/arigadicomando/lista.tsv

# estrai un geojson per ogni comune
mapshaper "$folder"/../../dati/arigadicomando/tmp.shp -split PRO_COM_T -o format=geojson "$folder"/../../dati/arigadicomando/output_noreg/

# rimuovi dai "poligoni buffer comune" l'area dei capoluoghi di provincia
parallel --colsep "\t" -j100% 'mapshaper ../../dati/arigadicomando/output_noreg/{1}.json -erase ../../dati/arigadicomando/capoluoghi_4326.shp -o precision=0.000001 ../../dati/arigadicomando/output_noreg/{1}.geojson' :::: ./../../dati/arigadicomando/lista.tsv
