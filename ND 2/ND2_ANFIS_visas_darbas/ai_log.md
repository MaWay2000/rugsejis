# AI agento panaudojimas

AI agentas panaudotas mokslinio straipsnio paieškai, metodikos analizei, oficialių EIA duomenų paruošimui, savarankiško MATLAB ANFIS algoritmo programavimui, vietiniam eksperimentų vykdymui, ateities prognozių sudarymui ir rezultatų tikrinimui.

Svarbiausi atlikti veiksmai:

1. Parinktas atviros prieigos straipsnis apie savaitinių benzino kainų prognozavimą.
2. Atsisiųstas oficialus EIA duomenų failas ir patikrinta straipsnyje naudota datos riba.
3. Nustatyta, kad vietiniame MATLAB neįdiegtas „Fuzzy Logic Toolbox“.
4. Sugeno ANFIS mokymas realizuotas baziniame MATLAB be papildomų bibliotekų.
5. Atkartoti bandymai be ankstesnės kainos ir su ankstesnės savaitės kaina.
6. Patikrinti mokymo ir testavimo imčių dydžiai, metrikos, išsaugoti modeliai ir grafikai.
7. Užfiksuoti straipsnio imties dydžio bei MSE ir RMSE reikšmių neatitikimai.
8. Kainų grafikai ir ateities prognozės perskaičiuoti iš USD už galoną į EUR už litrą, naudojant fiksuotą ECB kursą 1 EUR = 1,1403 USD.
9. Su visa turima EIA istorija sudarytos 52 savaičių ir savaitinė prognozė iki 2030 m. pabaigos.
10. Atnaujinti CSV, MAT, PNG, Word, PDF ir galutinis ZIP paketas; dokumentų puslapiai patikrinti po renderinimo.

Galutinės išvados bus grindžiamos MATLAB programos išsaugotomis prognozėmis ir CSV rezultatais, o ne vien AI agento tekstiniu vertinimu.

Ilgo laikotarpio prognozė vertinama atsargiai: ji yra rekursinė, todėl jos neapibrėžtumas didėja su kiekvienu žingsniu ir ji nėra finansinis ar kainų garantijos teiginys.
