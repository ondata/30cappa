#!/bin/bash

set -x

folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$folder"/../dati/rawdata

# confini amministrativi versione generalizzata #

URL_geo="https://www.istat.it/storage/cartografia/confini_amministrativi/generalizzati/Limiti01012020_g.zip"

# scarica i dati
curl -kL "$URL_geo" >"$folder"/../dati/rawdata/Limiti01012020_g.zip

# decomprimi dati
unzip "$folder"/../dati/rawdata/Limiti01012020_g.zip -d "$folder"/../dati/rawdata

# popolazione residente #

URL_pop="http://demo.istat.it/pop2020/dati/comuni.zip"

# scarica i dati
curl -kL "$URL_pop" >"$folder"/../dati/rawdata/comuni.zip

# decomprimi dati
unzip "$folder"/../dati/rawdata/comuni.zip -d "$folder"/../dati/rawdata
