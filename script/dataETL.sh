#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/../dati

### dati sulla popolazione ###

# rimuovi riga intestazione
tail <"$folder"/../dati/rawdata/comuni.csv -n +2 >"$folder"/../dati/comuni.csv

mlr -I --csv cut -x -f Età \
  then put '$Totale=${Totale Maschi}+${Totale Femmine}' \
  then cut -x -f Età \
  then stats1 -a sum -f Totale -g "Codice comune" \
  then clean-whitespace "$folder"/../dati/comuni.csv
