- [Il decreto “di Natale”, in chilometri](#il-decreto-di-natale-in-chilometri)
  - [Sono previsti spostamenti di 30 chilometri: ecco dove, quando e quanto](#sono-previsti-spostamenti-di-30-chilometri-ecco-dove-quando-e-quanto)
    - [Utility usate](#utility-usate)
    - [Lo script](#lo-script)
      - [Elaborazione dati sulla popolazione](#elaborazione-dati-sulla-popolazione)
      - [Elaborazione dati geografici](#elaborazione-dati-geografici)
      - [Elaborazione dati per il sito web](#elaborazione-dati-per-il-sito-web)
    - [Note conclusive](#note-conclusive)

# Il decreto “di Natale”, in chilometri

## Sono previsti spostamenti di 30 chilometri: ecco dove, quando e quanto

Con [Maurizio](https://twitter.com/napo) e [Salvatore](https://twitter.com/totofiandaca) abbiamo raccontato [**Il decreto “di Natale”, in chilometri**](https://medium.com/tantotanto/il-decreto-di-natale-in-chilometri-8af38744a7d5), ovvero come calcolare le aree in cui sarà possibile spostarsi nei giorni 28, 29, 30 dicembre 2020 e 4 gennaio 2021, secondo quanto indicato nel [Decreto Legge numero 172 del 18 dicembre 2020 ](https://www.gazzettaufficiale.it/eli/id/2020/12/18/20G00196/s).

Maurizio le ha calcolate usando [Python](https://github.com/ondata/30cappa/blob/main/script/conpython/README.md), Salvatore [con QGIS e SpatiaLite](https://pigrecoinfinito.com/2020/12/24/il-decreto-di-natale-in-chilometri); io l'ho fatto "**a riga di comando**", sfruttando alcune *utility* e uno [script *bash*](dataETL.sh).

### Utility usate

Lo script *bash* sfrutta principalmente queste 4 *utility*:

- **GDAL/OGR**, la più importante libreria *open source* per leggere e scrivere file geografici vettoriali e *raster* https://gdal.org/
- **Mapshaper**, una straordinaria applicazione *open source* per modificare file in formato Shapefile, GeoJSON, TopoJSON, CSV, ecc. https://github.com/mbloch/mapshaper
- **Miller**, una straordinaria applicazione *open source* per elaborare file in formato CSV, TSV, ecc. https://miller.readthedocs.io/en/latest/features.html
- **gnu parallel**, una straordinaria applicazione *open source*  per eseguire processi in parallelo https://www.gnu.org/software/parallel/.

Per usare lo *script*, è necessario che siano installate.

### Lo script

È diviso in tre parti:

- l'elaborazione dei dati sulla popolazione;
- l'elaborazione dei dati geografici;
- l'elaborazione per produrre i dati a supporto della mappa *online* che abbiamo realizzato.

#### Elaborazione dati sulla popolazione

Abbiamo scelto come **fonte** questa di **ISTAT**: <http://demo.istat.it/pop2020/dati/comuni.zip>.<br>Sono dati aggiornati a gennaio 2020 con queste caratteristiche:

- formato CSV;
  - *encoding* `UTF-8`;
  - la `,` come separatore di campi;
- 2 righe di intestazione, una descrittiva e una con i nomi dei campi;
- 5 campi
  - il codice ISTAT in formato numerico del comune;
  - il nome del comune;
  - la classe di età della popolazione, da `0` a `100` a passo di un anno, con uno speciale valore di `999` per il totale di popolazione per comune;
  - il totale di popolazione dei maschi;
  - il totale di popolazione delle femmine;
- per ogni comune un record per ogni classe di età.

Questo un estratto:

```
Popolazione residente al 1° Gennaio 2020 per età sesso e stato civile
Codice comune,Denominazione,Età,Totale Maschi,Totale Femmine
1001,Agliè,0,5,11
1001,Agliè,1,9,15
1001,Agliè,2,6,8
...,...,...,...,...
1001,Agliè,999,1236,1402
```

E queste le informazioni di sintesi sullo schema:

| field | type | min | max | min_length | max_length | mean | stddev | median | cardinality |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Codice comune | Integer | 1001 | 111107 | 4 | 6 | 45193.820597166 | 32622.60515262005 | 40034.5 | 7904 |
| Denominazione | Unicode | Abano Terme | Zungri | 2 | 34 |  |  |  | 7898 |
| Età | Integer | 0 | 999 | 1 | 3 | 59.30392156862904 | 97.90058875583414 | 50.5 | 102 |
| Totale Maschi | Integer | 0 | 1341940 | 1 | 7 | 72.78658857267648 | 2060.840107118411 | 10 | 4667 |
| Totale Femmine | Integer | 0 | 1495392 | 1 | 7 | 76.66526256251474 | 2266.2967872158915 | 11 | 4816 |

Per poterlo utilizzare è necessario rimuovere la prima riga di intestazione. Nello script è stata rimossa con [`tail`](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/tail.html#top), con l'opzione `-n` e l'argomento `2`, per avere in output il file a partire dalla seconda riga:

```bash
tail <./comuni.csv -n +2
```

Il passo successivo è quello di estrarre il totale di popolazione per comune. Per come è fatto il file, è necessario estrarre tutte le righe in cui `Età=="999"` e fare poi la somma del totale di maschi e femmine.<br>A questo è stata aggiunta l'estrazione dei campi `Codice comune` e `Abitanti` (e la rimozione dei restanti) e il loro cambio nome.<br>
Ho usato Miller:

```bash
mlr -I --csv clean-whitespace \
  then filter -S '${Età}=="999"' \
  then put '$Abitanti=${Totale Maschi}+${Totale Femmine}' \
  then cut -f "Codice comune",Abitanti \
  then rename "Codice comune",PRO_COM_T ./comuni.csv
```

La sintassi di Miller è molto leggibile. Qualche nota:

- ai nomi di campo si fa riferimento con `$` seguito da nome campo. Qui sono state aggiunte le parentesi graffe, perché siamo in presenza di nomi "speciali", con spazi e accentate;
- viene applicato il comando `clean-whitespace` (in Miller si chiamano "verbi"), per rimuovere eventuali spazi bianchi "in più", ovvero 1 o più a inizio e fine cella, e più di 1 tra caratteri in un cella;
- l'opzione `-I` fa in modo che il comando lavori in sovrascrittura sul file.

In ultimo si è scelto di `standardizzare` il codice ISTAT dei comuni, da campo numerico a campo testuale a 6 caratteri: ad esempio trasformare il codice `1001` del comune di Agliè in `001001`. <br>Usando in Miller il "verbo" [`put`](https://miller.readthedocs.io/en/latest/reference-verbs.html#put) e la fuzione [`fmtnum`](https://miller.readthedocs.io/en/latest/reference-dsl.html#fmtnum):

```bash
mlr -I --csv put '$PRO_COM_T=fmtnum($PRO_COM_T,"%06d")' ./comuni.csv
```

#### Elaborazione dati geografici

Ancora una volta la **fonte** è **ISTAT**, in particolare la versione generalizzata dei "confini delle unità amministrative a fini statistici":<br><https://www.istat.it/storage/cartografia/confini_amministrativi/generalizzati/Limiti01012020_g.zip>.

Sono dati aggiornati a gennaio 2020 con queste caratteristiche:

- formato Shapefile
  - *encoding* `UTF-8`;
  - sistema di coordinate [`EPSG:32632`](https://epsg.io/32632);
  - tipo geometrico `Polygon`;
- 13 campi, con i codici ISTAT di ogni comune a tutti i livelli amministrativi gerarchici, il nome, l'area e il perimetro del poligono che rappresenta il confine comunale
- un record per ogni comune italiano, quindi 7904 in totale.

Questo un estratto:

```
+---------+---------+----------+--------+---------+---------+-----------+-------------+----------+--------+-------------+-----------+
| COD_RIP | COD_REG | COD_PROV | COD_CM | COD_UTS | PRO_COM | PRO_COM_T | COMUNE      | COMUNE_A | CC_UTS | SHAPE_AREA  | SHAPE_LEN |
+---------+---------+----------+--------+---------+---------+-----------+-------------+----------+--------+-------------+-----------+
| 3       | 12      | 60       | 0      | 60      | 60037   | 060037    | Fontechiari | -        | 0      | 16270605.91 | 16457.49  |
| 2       | 5       | 28       | 0      | 28      | 28044   | 028044    | Legnaro     | -        | 0      | 15712001.07 | 17663.17  |
| 3       | 9       | 46       | 0      | 46      | 46031   | 046031    | Vagli Sotto | -        | 0      | 41459091.05 | 28108.08  |
| 3       | 12      | 56       | 0      | 56      | 56034   | 056034    | Marta       | -        | 0      | 33594560.89 | 26695.50  |
| 2       | 8       | 37       | 237    | 237     | 37035   | 037035    | Malalbergo  | -        | 0      | 54059370.35 | 42717.13  |
+---------+---------+----------+--------+---------+---------+-----------+-------------+----------+--------+-------------+-----------+
```

E queste le informazioni di sintesi sullo schema:

| field | type | min | max | min_length | max_length | mean | stddev | median | mode | cardinality |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| COD_RIP | Integer | 1 | 5 | 1 | 1 | 2.4862095141700404 | 1.4286548784684956 | 2 | 1 | 5 |
| COD_REG | Integer | 1 | 20 | 1 | 2 | 8.659286437246942 | 6.388341980201931 | 7 | 3 | 20 |
| COD_PROV | Integer | 1 | 111 | 1 | 3 | 45.130819838056745 | 32.64463443546327 | 40 | 1 | 107 |
| COD_CM | Integer | 0 | 292 | 1 | 3 | 38.92054655870437 | 90.042657529667 | 0 | 0 | 16 |
| COD_UTS | Integer | 2 | 292 | 1 | 3 | 77.22039473684187 | 79.31575427084252 | 57 | 201 | 108 |
| PRO_COM | Integer | 1001 | 111107 | 4 | 6 | 45193.82059716597 | 32622.605152620454 | 40034.5 | N/A | 7904 |
| PRO_COM_T | Unicode | 001001 | 111107 | 6 | 6 |  |  |  | N/A | 7904 |
| COMUNE | Unicode | Abano Terme | Zungri | 2 | 34 |  |  |  | N/A | 7898 |
| COMUNE_A | Unicode | Abtei | Števerjan | 0 | 36 |  |  |  |  | 125 |
| CC_UTS | Integer | 0 | 1 | 1 | 1 | 0.013790485829959558 | 0.1166203598456684 | 0 | 0 | 2 |
| SHAPE_AREA | Float | 103841.59 | 1286515935.04 | 9 | 13 | 38212174.82759485 | 50775638.830618076 | 22462066.48 | N/A | 7904 |
| SHAPE_LEN | Float | 1327.5 | 279961.61 | 7 | 9 | 28724.054496457524 | 19071.825497349204 | 23815.9 | N/A | 7898 |

Come scritto nell'[**articolo che presenta il progetto**](https://medium.com/tantotanto/il-decreto-di-natale-in-chilometri-8af38744a7d5), dato un comune con non più di **5.000 abitanti**, e il suo confine, per calcolare l'area in cui da questo è possibile spostarsi (nei giorni 28, 29, 30 dicembre 2020 e 4 gennaio 2021), è necessario per ogni comune:

- calcolare l'area di **buffer** attorno al confine, di **30.000 metri**;
- rimuovere da questa l'eventuale **area** dei **comuni** **capoluogo** che ricadono all'interno;
- rimuovere la parte che va **al di fuori** dei **confini nazionali**.

Il *buffer*, il luogo dei punti distanti 30.000 metri dal confine comunale, è stato calcolato tramite `ogr2ogr`:

```bash
ogr2ogr -t_srs EPSG:4326 ./comuni_30cappa_5mila.shp ./comuni.shp \
-dialect sqlite \
-sql "SELECT PRO_COM_T,COD_REG,COMUNE,Abitanti,st_buffer(comuni.geometry,30000) AS geom FROM comuni where Abitanti <= 5000"
```

Alcune note:

- come sistema di coordinate di *output* è stato scelto `EPSG:4326`, perché compatibile in modo nativo con le librerie per la pubblicazione di mappe sul *web*;
- il *buffer* viene calcolato tramite una interrogazione `SQL` di tipo spaziale, sfruttando il dialetto `sqlite` e la funzione [`ST_BUFFER`](https://www.gaia-gis.it/gaia-sins/spatialite-sql-latest.html#:~:text=space\)-,Buffer). Questa vuole come argomenti la colonna geometrica e la distanza (di *default* usando l'unità di misura nativa, che qui sono metri);
- vengono estratte soltanto le colonne utili per l'applicazione creata (codice comunale a 6 caratteri, codice regionale numerico e numero di abitanti).

I **poligoni** dei **capoluoghi** sono tutti quelli che ne *file* di *input* hanno `CC_UTS==1`. Vengono estratti con [`Mapshaper`](https://github.com/mbloch/mapshaper/wiki/Command-Reference):

```bash
mapshaper ./comuni.shp \
-filter 'CC_UTS==1' \
-filter-fields PRO_COM_T,COD_REG,COMUNE,Abitanti \
-proj wgs84 \
-o ./capoluoghi_4326.shp
```

La sintassi di Mapshaper è molto leggibile. Vengono estratti soltanto alcuni campi (come nella creazione dei *buffer*) e per le ragioni precedenti viene scelto `EPSG:4326` come sistema di coordinare di *output*.

Per creare il **limite** **poligonale** dello **stato** **italiano**, basta unire - fare il *dissolve* - dei poligoni dei comuni del file di *input*.<br>Con `Mapshaper`:

```bash
mapshaper ./comuni.shp -dissolve \
-proj wgs84 \
-o precision=0.000001 ./italia.shp
```

Il comando [`dissolve`](https://github.com/mbloch/mapshaper/wiki/Command-Reference#-dissolve) è il cuore del processo e ancora una volta in *output* `EPSG:4326`.

Questo *output* viene usato per **ritagliare** le aree di *buffer* dei comuni. Su utilizza il comando [`clip`](https://github.com/mbloch/mapshaper/wiki/Command-Reference#-clip) di Mapshaper:

```bash
mapshaper ./comuni_30cappa_5mila.shp -clip ./italia.shp -o ./output.shp
```

#### Elaborazione dati per il sito web

La pagina web per presentare le aree in cui - per ogni comune - è possibile spostarsi ha una struttura di `URL` di questo tipo:<br>
`https://ondata.github.io/30cappa/mappa.html?id=067042`.

Al cambio di `id`, che qui è il codice ISTAT a caratteri del comune di proprio interesse - viene aperta una mappa centrata sul *buffer* di quel comune, con evidenziate l'area in cui è possibile spostarsi e il limite comunale.

![](https://i.imgur.com/g5N62r4.png)

Quindi indicato ad esempio l'identificativo `067042`, devono essere visualizzate due geometrie distinte.<br>
Quella del comune viene restituita in risposta a un'interrogazione alle [API SQL di CARTO](https://carto.com/developers/sql-api/), mentre quella del buffer è una chiamata diretta al file `
GeoJSON` del buffer di 30.000 metri del confine di un dato comune.<br>
Era quini necessario generare **5.496 file**, perché tanti sono i comuni con abitanti `<=5.000`.

Per farlo è stata creato un file TSV con la lista, con le colonne con il codice del comune e il codice regionale:

```bash
ogr2ogr -f CSV /vsistdout/ ./comuni_30cappa_5mila.shp | \
mlr --c2t clean-whitespace then cut -f PRO_COM_T,COD_REG | \
tail -n +2 >./lista.tsv
```

Alcune note:

- viene usato `ogr2ogr` per trasformare lo Shapefile in `CSV` e passarlo allo *standard output*, tramite l'opzione `/vsistdout/`;
- lo *standard output* viene passato a Miller per rimuovere eventuali spazi bianchi ridondanti, estrarre le sole colonne `PRO_COM_T` e `COD_REG` e convertire tutto in `TSV`;
- viene rimossa la riga di intestazione tramite `tail`.

In output qualcosa come

```
011006  7
043022  11
064042  15
075049  16
026014  5
```

A partire dal file che contiene i *buffer* dei 5.496 comuni, viene estratto un file `GeoJSON` per ogni codice comunale distinto:

```bash
mapshaper ./input.shp -split PRO_COM_T -o format=geojson ./output_noreg/
```

A partire dal file di input, sfruttando il comando [`split`](https://github.com/mbloch/mapshaper/wiki/Command-Reference#-split) di Mapshaper, verranno creati in file `GeoJSON` nella cartella `output_noreg`.

In ultimo è necessario rimuovere dai poligoni di *buffer* , ovvero da questi file generati, le aree che corrispondono ai limiti dei comuni capoluogo (verso cui non sarà possibile spostarsi).

In termini di logica di *script* e di *performance*, sarebbe meglio farlo direttamente a partire dal singolo file con tutti i buffer dei comuni. <br>
L'ideale sarebbe farlo in Mapshaper - per snellezza e rapidità del comando - ma sembra che ci sia un baco e quindi non è possibile farlo "in blocco".<br>
Un'alternativa potrebbe essere utilizzare di nuovo `ogr2ogr`, con una query `sqlite`, ma non ha grandi *perfomance*.<br>
O - sempre per stare con le *utility* a riga di comando - farlo con `spatialite`. Ma questo lo ha già fatto Salvatore e vi invito a guardare le sue [query](../QGIS/scriptSQL/script.sql).

Qui è stato fatto in parallelo con `parallel` e `Mapshaper`, rimuovendo le aree dei comuni capoluogo da ogni `GeoJSON` con il *buffer* sul limite comunale .<br>
La lista dei comuni creata sopra, viene usata come argomento di `parallel`.

```bash
parallel --colsep "\t" -j100% 'mapshaper ./output_noreg/{1}.json \
-erase ./capoluoghi_4326.shp \
-o precision=0.000001 ./output_noreg/{1}.geojson' :::: ./lista.tsv
```

Alcune note:

- si fa riferimento alle colonne del `TSV` di input, tramite numeri interi a partire da 1 e circondati da graffe. Quindi la prima colonna sarà `{1}`;
- il comando [`erase`](https://github.com/mbloch/mapshaper/wiki/Command-Reference#-erase) di MapShaper è quello che si occupa del processo principale;
- l'opzione di *output* `precision=0.000001` viene usata per impostare a 6 decimale la precisione delle coordinate dei file `GeoJSON` di *output* (lo prevedono le [specifiche del formato](https://tools.ietf.org/html/rfc7946)).


### Note conclusive

Lo [script *bash*](dataETL.sh) non è perfettamente coincidente con quanto descritto in questo articolo.<br>Qui alcuni comandi sono stati leggermente modificati a vantaggio di una maggiore leggibilità.

Si sarebbe potuta usare anche una sola di queste *utility* per fare tutto. Ma alcune sono più *easy* e rapidi in certi operazioni e questa era una buona occasione per "toccare" un po' 4 straordinari esempi di applicazione *open source* a riga di comando.
