# -*- coding: utf-8 -*-
"""30cappa.ipynb


# 30cappa con meno di 5mila abitanti

![](https://raw.githubusercontent.com/aborruso/30cappa/main/risorse/2020-12-18_slide_Natale.png)

- trovare i piccoli Comuni (fino a 5mila abitanti)
- calcolare i 30kmdal confine  da cui possono spostare
- impedendo di andare nei Comuni capoluogo di Provincia e rimanendo nella stessa regione o Provincia Autonoma.

## Setup

queste istruzoni possono essere commentate
"""

#!pip install requests

#!pip install pandas

#!pip install geopandas

#!pip install pygeos

import pandas as pd
import geopandas as gpd
import os
import requests, zipfile, io
import matplotlib.pyplot as plt

"""# Raccolta dei dati
- confini comunali
- statistiche popolazione

## Confini dei comuni d'Italia

ISTAT offre gli shapefile delle unità amministrative
https://www.istat.it/it/archivio/222527

Ciascun archivio è un file zip che contiene diverse unità amministrative: macroregioni, regioni, province e comuni.
Alcuni campi significativi:
- PRO_COM_T è il codice univoco per ogni comune assegnato da ISTAT
- *CC_UTS* quando il valore è uguale a 1 significa che si tratta di un comune capoluogo di provincia
- *COD_REG* è il codice univoco della regione assegnato da ISTAT

**NOTE**<br/>
- le geometrie dei confini comunali sono archiviate con proiezione [WGS 84 / UTM zone 32N](https://epsg.io/32632), quindi in metri
- molti comuni hanno [enclave ed exclave](https://it.wikipedia.org/wiki/Enclave_ed_exclave) con il risultato che il confine comunale è composto da aree non contigue fra di loro
- un caso particolare è il comune di [Campione d'Italia](https://it.wikipedia.org/wiki/Campione_d%27Italia) che è al di fuori dal confine italiano
- le province autonome di Trento e Bolzano, in questo caso, vanno considerate come regioni, quindi bisogna guardare anche il valore *COD_PROV*.la Regione Trentino Alto Adige ha COD_REG con valore 4, la provincia di Bolzano ha valore COD_PROV=21 mentre Trento COD_PROV=22


**download dei dati**
"""

# indirizzo del file
zip_file_url = 'https://www.istat.it/storage/cartografia/confini_amministrativi/non_generalizzati/Limiti01012020.zip'
#download
r = requests.get(zip_file_url)
z = zipfile.ZipFile(io.BytesIO(r.content))
#decompressione
z.extractall()

"""**geodataframe con i limiti comunali**"""

limiti_comuni = gpd.read_file("Limiti01012020" + os.sep + "Com01012020" + os.sep + "Com01012020_WGS84.shp",encoding='utf-8')

"""**ottenere l'elenco dei capoluoghi di provincia**

CC_UTS = 1
"""

comuni_capoluoogo_provincia = limiti_comuni[limiti_comuni.CC_UTS == 1][['COMUNE','PRO_COM_T']]

# visualizzare i primi 5
comuni_capoluoogo_provincia.head(5)

"""export della tabella in formato csv"""

comuni_capoluoogo_provincia.to_csv("comuni_capoluoogo_provincia.csv")

"""## Informazioni statistiche sulla popolazione in Italia

ISTAT offre il sito https://demo.istat.it che rilascia dati aggiornati con cadenza periodica.

L'ultimo elenco disponibile è quello di gennaio 2020

Il file con i dati per comune si trova qui http://demo.istat.it/pop2020/dati/comuni.zip
"""

dati_demografici_comuni_italiani = "http://demo.istat.it/pop2020/dati/comuni.zip"

"""nonostante lo zip contenga un CSV la prima riga va cancellata in quanto è usata come titolo del dataset, pertanto bisogna partire dalla seconda (*skiprows=1*).<br/>
La codifica caratteri è *utf-8*
"""

demo_comuni = pd.read_csv(dati_demografici_comuni_italiani,skiprows=1,encoding='utf-8')

"""visualizzazione prime righe"""

demo_comuni.head(5)

"""**note**<br/>
ogni riga è organizzata per fasce d'età (campo *Età*), il valore *999* contiene il totale.<br/>
Occorre quindi filtrare il csv per il valore *999*


quindi è necessario filtrare per quel valore
"""

comuni_popolazione = demo_comuni[demo_comuni.Età == 999]

"""per calcolare il totale della popolazione è necessario sommare *Totale Femmine* con *Totale Maschi*"""

comuni_popolazione['POPOLAZIONE'] = comuni_popolazione.loc[:, ('Totale Femmine', 'Totale Maschi')].sum(axis=1)

"""dalla tabella creata prendiamo solo le colonne utili

"""

comuni_popolazione = comuni_popolazione[['Codice comune','Denominazione','POPOLAZIONE']]

"""per comodità nelle operazioni successive conviene rinominare le colonne allo stesso modo di quelle del file con i confini comunali"""

comuni_popolazione.rename(columns={'Codice comune':'PRO_COM_T','Denominazione':'COMUNE'}, inplace=True)

"""**elenco dei 'piccoli Comuni'**

la definizione dice "fino a 5000 abitanti" 
"""

piccoli_comuni = comuni_popolazione[comuni_popolazione.POPOLAZIONE <= 5000]

"""vediamo quanti sono"""

piccoli_comuni.shape[0]

"""esportazione del file in formato .csv"""

piccoli_comuni.to_csv("piccoli_comuni.csv")

"""*nota*<br/>
Quanti sono i comuni fra i 5001 e 5020 abitanti?

"""

comuni5001_5020 = comuni_popolazione[(comuni_popolazione.POPOLAZIONE >= 5001) & (comuni_popolazione.POPOLAZIONE <= 5020)]

"""quanti sono i comuni in questione"""

comuni5001_5020.shape[0]

"""quali sono in ordine crescente di popolazione"""

comuni5001_5020.sort_values('POPOLAZIONE')

"""## trovare l'area a 30km di raggio dal confine dei piccoli comuni

operazioni da svolgere:
- aggiungere ai dati dei confini comunali l'attributo della popolazione per ciascun comune
- l'area a 30cappa si calcola usando la funzione [buffer](https://geopandas.org/geometric_manipulations.html#GeoSeries.buffer)
- a questa va sottratta: 
  - l'area dei confini regionali (o della provincia autonoma)
  - l'area del comune capoluogo si provincia

come output generiamo un file geojson per ogni comune e associamo anche la lista dei comuni a 30km di distanza nel campo *comunia30cappa*

estendere alle geometrie il valore della popolazione
"""

comuni_popolazione_tojoin = comuni_popolazione[['PRO_COM_T','POPOLAZIONE']]

"""per fare la join è necessario che entrambi i campi siano dello stesso tipo ( = intero)"""

limiti_comuni["PRO_COM_T"] = pd.to_numeric(limiti_comuni["PRO_COM_T"] , downcast='integer')

geo_comuni_popolazione = limiti_comuni.merge(comuni_popolazione_tojoin,on='PRO_COM_T')

"""**inizio del calcolo**

a causa del fatto che bisogna prendere in considerazione il confine regionale andiamo a fare il calcolo dei comuni per ogni regione (o provincia autonoma)
"""

def area30Cappa(comune,regione,gdf_confine):
  # creazione dell'area a 30cappa dal confine
  comune['geometry'] = comune.geometry.buffer(30000)
  # taglio sul confine regionale
  comune = gpd.overlay(comune,gdf_confine, how='intersection')
  # spatial join al fine di avere i nomi dei comuni che intersecano l'area
  # nota: l'intersezione aggiunge i suffissi _right
  comuni_raggiungibili = gpd.sjoin(comune,regione)[['COMUNE_right','PRO_COM_T_right','CC_UTS']]
  # pulizia del suffisso
  for col in comuni_raggiungibili.columns:
    comuni_raggiungibili.rename(columns={col:col.replace("_right","")},inplace=True)
  # esclusione dell'aree dei comuni capoluogo
  capoluoghi = []
  for cod_capoluogo in comuni_raggiungibili[comuni_raggiungibili.CC_UTS==1].PRO_COM_T.unique():
    capoluogo = regione[regione.PRO_COM_T == cod_capoluogo].reset_index()
    capoluoghi.append(capoluogo.COMUNE.values[0])
    # creazione della nuova geometria
    comune = gpd.overlay(comune,capoluogo,how='difference')
  comuni_30cappa = ""
  lista_comuni = list(comuni_raggiungibili.COMUNE.unique())
  for ncapoluogo in capoluoghi:
    lista_comuni.remove(ncapoluogo)
  for nome in lista_comuni:
      comuni_30cappa += nome + " ,"
  comuni_30cappa = comuni_30cappa.lstrip(" ,")
  # aggiunta dell'elenco dei comuni raggiungibili
  comune['30CAPPA'] = comuni_30cappa
  # selezione dei campi utili allo scopo
  comune = comune[['COMUNE','PRO_COM_T','POPOLAZIONE','30CAPPA','geometry']]
  return(comune)

#variabile per raccogliere tutti i comuni
tutti_i_comuni = []
for cod_reg in geo_comuni_popolazione.COD_REG.unique():
  # quando cod_reg vale 4 vuole dire che siamo davanti alla regione Trentino Alto Adige
  # quindi dobbiamo guardare per le province
  if (cod_reg != 4):
    #estrazione dei comuni per regione
    regione = geo_comuni_popolazione[geo_comuni_popolazione['COD_REG'] == cod_reg]
    #calcolo della geometria del confine regionale
    confine_regionale = regione.geometry.unary_union
    #trasformazione in geodataframe per necessità delle funzioni di overlay
    #di geopandas
    gdf_confine = gpd.GeoDataFrame(
        pd.DataFrame(data={'regione': [cod_reg]}),
        crs='EPSG:32632',
        geometry=gpd.GeoSeries(confine_regionale))
    #estrazione dei piccoli comuni per questa regione
    piccoli_comuni = regione[regione.POPOLAZIONE <= 5000]
    #inizio del calcolo dell'area del comune a 30cappa dal confine e
    #sottrazione dei confini regionali e dei comuni capoluogo dall'area trovata
    #per ciascun comune
    for codice in piccoli_comuni.PRO_COM_T.unique():
      # estrazione singolo comune
      comune = piccoli_comuni[piccoli_comuni['PRO_COM_T'] == codice].reset_index()
      comune = comune[['COMUNE','PRO_COM_T','POPOLAZIONE','geometry']]
      nome = str(comune['PRO_COM_T'].values[0])
      comune.to_crs(epsg=4326).to_file(nome + ".geojson",driver="GeoJSON")
      comune = area30Cappa(comune,regione,gdf_confine)
      ## creazione del file geojson
      comune.to_crs(epsg=4326).to_file(nome + "_a30cappa.geojson",driver="GeoJSON")
      tutti_i_comuni.append(comune)
  else:
    # questo è il caso in cui si tratta delle Province autonome
    codici_provincia = [21,22]
    for cod_prov in codici_provincia:
      provincia = geo_comuni_popolazione[geo_comuni_popolazione['COD_PROV'] == cod_prov]
      confine_provinciale = pat.geometry.unary_union
      gdf_confine = gpd.GeoDataFrame(
        pd.DataFrame(data={'regione': [cod_prov]}),
        crs='EPSG:32632',
        geometry=gpd.GeoSeries(confine_provinciale))
      for codice in piccoli_comuni.PRO_COM_T.unique():
        # estrazione singolo comune
        comune = piccoli_comuni[piccoli_comuni['PRO_COM_T'] == codice].reset_index()
        comune = comune[['COMUNE','PRO_COM_T','POPOLAZIONE','geometry']]
        nome = str(comune['PRO_COM_T'].values[0])
        comune.to_crs(epsg=4326).to_file(nome + ".geojson",driver="GeoJSON")
        comune = area30Cappa(comune,provincia,gdf_confine)
        ## creazione del file geojson
        comune.to_crs(epsg=4326).to_file(nome + "_a30cappa.geojson",driver="GeoJSON")
        tutti_i_comuni.append(comune)

finoa5mila30cappa = gpd.GeoDataFrame( pd.concat( tutti_i_comuni, ignore_index=True) )

finoa5mila30cappa.to_crs(epsg=4326).to_file('finoa5mila30cappa.geojson',driver="GeoJSON")

files.download("finoa5milatrentino.geojson")