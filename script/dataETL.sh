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

# applica zero padding ai codici comunali
