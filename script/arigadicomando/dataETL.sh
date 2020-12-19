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

# crea geojson dei comuni
mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -proj wgs84 -o format=geojson "$folder"/../../dati/arigadicomando/comuni.geojson

# genera buffer a 30 kilometri dei comuni con meno di 5001 abitanti
ogr2ogr "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp "$folder"/../../dati/arigadicomando/comuni.shp -dialect sqlite -sql "SELECT PRO_COM_T,COD_REG,COMUNE,Abitanti,st_buffer(comuni.geometry,30000) AS geom FROM comuni where Abitanti <= 5000" -explodecollections

# estrarre capoluoghi di provincia
mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -filter 'CC_UTS==1' -filter-fields PRO_COM_T,COD_REG,COMUNE,Abitanti -o "$folder"/../../dati/arigadicomando/capoluoghi.shp
mapshaper "$folder"/../../dati/arigadicomando/capoluoghi.shp -proj wgs84 -o "$folder"/../../dati/arigadicomando/capoluoghi_4326.shp

# crea Italia
mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -dissolve -o "$folder"/../../dati/arigadicomando/italia.shp

# ritagliare i buffer dei comuni con il limite dell'italia
mapshaper "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp -clip "$folder"/../../dati/arigadicomando/italia.shp -o "$folder"/../../dati/arigadicomando/tmp.shp

# crea CSV di servizio
ogr2ogr -f CSV "$folder"/../../dati/arigadicomando/capoluoghi.CSV "$folder"/../../dati/arigadicomando/capoluoghi.shp
mlr -I --csv clean-whitespace "$folder"/../../dati/arigadicomando/capoluoghi.CSV

ogr2ogr -f CSV "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.CSV "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp
mlr -I --csv clean-whitespace "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.CSV

# crea lista codici comuni
mlr --c2t cut -f PRO_COM_T,COD_REG "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.CSV | tail -n +2 >"$folder"/../../dati/arigadicomando/lista.tsv

# rimuovi dai buffer le aree dei capoluogo
#mapshaper "$folder"/../../dati/arigadicomando/tmp.shp  -erase "$folder"/../../dati/arigadicomando/capoluoghi.shp -o "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp

# crea poligoni delle regioni
#rm "$folder"/../../dati/arigadicomando/risorse/*.geojson
#for i in {1..20}; do
#  mapshaper "$folder"/../../dati/arigadicomando/comuni.shp -filter 'COD_REG=="'"$i"'"' -dissolve -proj wgs84 -o "$folder"/../../dati/arigadicomando/risorse/"$i".geojson
#done

#rm "$folder"/../../dati/arigadicomando/output/*.geojson
while IFS=$'\t' read -r comune regione; do
  # estrai poligono buffer comune
  mapshaper "$folder"/../../dati/arigadicomando/comuni_30cappa_5mila.shp -filter 'PRO_COM_T=="'"$comune"'"' -proj wgs84 -o precision=0.000001 "$folder"/../../dati/arigadicomando/output/"$comune".geojson
  # rimuovi da poligono buffer comune area dei capoluoghi
  mapshaper "$folder"/../../dati/arigadicomando/output/"$comune".geojson -erase "$folder"/../../dati/arigadicomando/capoluoghi_4326.shp -o precision=0.000001 "$folder"/../../dati/arigadicomando/output/tmp.geojson
  # ritaglia poligono buffer comune su limite regionale
  mapshaper "$folder"/../../dati/arigadicomando/output/tmp.geojson -clip "$folder"/../../dati/arigadicomando/risorse/"$regione".geojson -o precision=0.000001 "$folder"/../../dati/arigadicomando/output/"$comune".geojson
done <"$folder"/../../dati/arigadicomando/lista.tsv

# cancella file di servizio
rm "$folder"/../../dati/arigadicomando/output/tmp.geojson
