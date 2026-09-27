# ND2 Benzino kainos prognozavimas su ANFIS

Studentas: Mantas Matusevičius
Grupė: DISfm-26

Darbas atkartoja straipsnio „Optimal Gasoline Price Predictions: Leveraging the ANFIS Regression Model“ eksperimentus su oficialiais JAV Energetikos informacijos administracijos EIA savaitinių benzino kainų duomenimis. Papildomai sudarytos 52 savaičių ir ilgalaikė prognozė iki 2030 m.

## Paleidimas

Paprasčiausia dukart paspausti `paleisti_lokaliai.bat`.

PowerShell aplinkoje galima paleisti ir tiesiogiai:

```powershell
& "C:\Program Files\MATLAB\R2026a\bin\matlab.exe" -batch "run('ND2.m')"
```

MATLAB redaktoriuje atidarykite `ND2.m` ir spauskite **Run**.

Programa naudoja tik bazinį MATLAB ir nereikalauja „Fuzzy Logic Toolbox“. Sugeno ANFIS mokymas realizuotas pačiame `ND2.m` faile: Gauso narystės funkcijų parametrai mokomi Adam metodu, o taisyklių išvadų parametrai – mažiausių kvadratų metodu.

## Atkuriami bandymai

1. ANFIS prognozė pagal dieną, mėnesį ir metus.
2. ANFIS prognozė papildomai naudojant ankstesnės savaitės kainą.
3. Su visa turima EIA istorija apmokyto modelio 52 savaičių prognozė.
4. Rekursinė savaitinė prognozė iki 2030 m. pabaigos.

Straipsnio atkūrimo bandymuose naudojamos dvi Gauso narystės funkcijos vienam požymiui, 100 mokymo epochų, 1 051 mokymo ir 451 testavimo pavyzdys. Ateities prognozei modelis papildomai apmokomas su visa turima EIA istorija.

Straipsnio metrikos paliekamos originaliu USD už galoną masteliu, kad jas būtų galima tiesiogiai palyginti su publikacija. Grafikai ir ateities prognozės pateikiami EUR už litrą, naudojant fiksuotą ECB kursą `1 EUR = 1,1403 USD` ir santykį `1 JAV galonas = 3,785411784 l`.

## Failai

- `ND2.m` – pagrindinė MATLAB programa.
- `data/EIA_weekly_gasoline_prices.xls` – originalus EIA failas.
- `data/EIA_straipsnio_duomenys.csv` – iki straipsnio pabaigos atrinkti 1 583 įrašai.
- `source/Eliwa_2024_ANFIS_gasoline.pdf` – pasirinktas mokslinis straipsnis.
- `ANFIS_rezultatai` – CSV rezultatai, modeliai ir grafikai.
- `ANFIS_rezultatai/metu_prognoze.csv` – 52 savaičių prognozė EUR/l.
- `ANFIS_rezultatai/prognoze_iki_2030.csv` – 223 savaičių prognozė iki 2030 m. EUR/l.
- `ataskaita` – galutinė Word ir PDF ataskaita.
- `ND2_LSTM_atsargine_kopija.zip` – ankstesnės ND2 temos atsarginė kopija.

## Straipsnyje aptikti neatitikimai

EIA duomenyse nuo 1993-04-05 iki 2023-07-31 yra 1 583 įrašai, tačiau straipsnyje nurodytos 1 051 ir 451 imtys sudaro tik 1 502 įrašus. Atkuriant naudoti pirmieji 1 502 įrašai, kad imčių dydžiai sutaptų.

Straipsnio MSE ir RMSE poros matematiškai nesuderinamos: RMSE turi būti MSE kvadratinė šaknis. Todėl ataskaitoje publikuotos reikšmės pateikiamos tokios, kokios paskelbtos, o atkurtos reikšmės skaičiuojamos tiesiogiai iš prognozių.

Prognozė iki 2030 m. yra papildomas demonstracinis eksperimentas. Kadangi kiekvienos naujos savaitės prognozė naudojama kaip kitos savaitės įvestis, ilgėjant horizontui neapibrėžtumas didėja; rezultatas nėra laikomas garantuota kuro kainų prognoze.

## Šaltiniai

- Eliwa, E. H. I., El Koshiry, A. M., Abd El-Hafeez, T. ir Omar, A. „Optimal Gasoline Price Predictions: Leveraging the ANFIS Regression Model“. *International Journal of Intelligent Systems*, 2024. https://doi.org/10.1155/2024/8462056
- U.S. Energy Information Administration. Weekly U.S. All Grades All Formulations Retail Gasoline Prices. https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?n=PET&s=EMM_EPM0_PTE_NUS_DPG&f=W
