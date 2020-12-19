#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/../../dati
mkdir -p "$folder"/../../dati/arigadicomando

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

# crea geojson dei comuni
mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -proj wgs84 -o format=geojson "$folder"/../../dati/arigadicomando/comuni.geojson

