#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/../dati

### dati sulla popolazione ###

# rimuovi riga intestazione
tail <"$folder"/../dati/rawdata/comuni.csv -n +2 >"$folder"/../dati/comuni.csv

# crea totale popolazione per codice comunale
mlr -I --csv cut -x -f Età \
  then put '$Totale=${Totale Maschi}+${Totale Femmine}' \
  then cut -x -f Età \
  then stats1 -a sum -f Totale -g "Codice comune" \
  then clean-whitespace then rename "Codice comune",PRO_COM_T,Totale_sum,Abitanti "$folder"/../dati/comuni.csv

# applica zero padding ai codici comunali, da 1001 a 001001
mlr -I --csv put '$PRO_COM_T=fmtnum($PRO_COM_T,"%06d")' "$folder"/../dati/comuni.csv

# estrai comuni <= 5000 abitanti
#mlr -I --csv filter '$Abitanti<=5000' "$folder"/../dati/comuni.csv

### dati geografici ###

# pulizia topologica di base
mapshaper "$folder"/../dati/rawdata/Limiti01012020_g/Com01012020_g/Com01012020_g_WGS84.shp -clean gap-fill-area=0 -filter 'COD_REG==19' -o "$folder"/../dati/tmp.shp

# JOIN con CSV per abitanti
mapshaper "$folder"/../dati/tmp.shp -join "$folder"/../dati/comuni.csv keys=PRO_COM_T,PRO_COM_T field-types=PRO_COM_T:str -o "$folder"/../dati/comuni.shp

