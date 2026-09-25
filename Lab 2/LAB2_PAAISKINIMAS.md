# 2 laboratorinis: daugiasluoksnio perceptrono mokymas MATLAB

Užduotis: https://github.com/serackis/IS-Lab2

## Pagrindinis atsiskaitymo variantas

Naudok `start.m`. Jis jau įkeltas į MATLAB Drive aplanką `/2026 rugsejis/2 lab`, paleistas ir patikrintas MATLAB Online R2026a.

Šis failas suderintas su pateiktomis teorijos nuotraukomis:

- 20 mokymo taškų intervale `[0,1]`;
- tinklo struktūra 1–5–1;
- penki sigmoidiniai paslėptojo sluoksnio neuronai;
- vienas tiesinis išėjimas;
- mokymas po vieną pavyzdį;
- mokymosi žingsnis `eta = 0.3`;
- savarankiškai parašytas Backpropagation, be `newff`, `train`, `sim`.

Paslėptojo sluoksnio atsakas ir jo išvestinė:

```text
y1 = 1/(1 + exp(-(w1*x+b1)))
y1' = y1*(1-y1)
```

Atgalinio sklidimo žingsnis:

```text
e = d-y
delta1 = y1*(1-y1) * (w2'*e)
w2 = w2 + eta*e*y1'
b2 = b2 + eta*e
w1 = w1 + eta*delta1*x
b1 = b1 + eta*delta1
```

Patikrintas rezultatas: 34 200 epochų, mokymo MSE `9.999624e-06`, o tankaus 401 taško tinklelio MSE `6.6056044e-06`. `delta1` kode apskaičiuojama prieš atnaujinant `w2`, kad visi vieno žingsnio gradientai remtųsi tais pačiais svoriais.

## Išplėsto varianto paleidimas

Toliau aprašytas `lab2.m` yra atskiras išplėstas variantas su papildoma paviršiaus aproksimavimo užduotimi. MATLAB programoje pasirink šį darbo aplanką kaip **Current Folder**.
2. Atidaryk `lab2.m` ir paspausk **Run** arba Command Window įrašyk `lab2`.
3. Programa išsprendžia pagrindinę ir papildomą užduotis. Grafikus ir išmokytus svorius išsaugo aplanke `lab2_rezultatai`.

Papildomų įrankių rinkinių nereikia. Programa patikrinta su MATLAB R2026a; senesnėse versijose `exportgraphics` gali būti neprieinama. Kartojant paleidimą šio laboratorinio rezultatų failai perrašomi.

## Kas realizuota

| Reikalavimas | Sprendimas |
|---|---|
| 20 įėjimo reikšmių intervale [0,1] | `linspace(0,1,20)` |
| Vienas paslėptasis sluoksnis, 4–8 neuronai | 8 neuronai su `tanh` |
| Vienas tiesinis išėjimas | Svertinė suma su poslinkiu |
| Savarankiškai parašytas atgalinis sklidimas | Funkcija `trainMLP`, išvestinės skaičiuojamos tiesiogiai |
| Perceptrono koeficientai | `W1`, `b1`, `W2`, `b2`, išsaugomi MAT faile |
| Papildoma paviršiaus užduotis | Atskiras tinklas su 2 įėjimais ir 1 išėjimu |

Pagrindinės užduoties formulė interpretuota taip, pataisant aprašo skliaustų klaidą:

```matlab
y = (1 + 0.6*sin(2*pi*x/0.7) + 0.3*sin(2*pi*x))/2;
```

Papildomai pasirinktas paviršius `y = 0.5 + 0.25*sin(pi*x1) + 0.25*cos(pi*x2)`. Jo formulės užduotis nenustato. Mokoma 15 × 15 tinklelyje (225 pavyzdžiai).

## Kaip veikia tinklas

Duomenų matricos **stulpelis yra vienas mokymo pavyzdys**. Pagrindinėje dalyje X dydis yra 1 × 20, papildomoje – 2 × 225. Įėjimai perskaičiuojami į [-1,1]: `U = 2*X-1`. Tai nekeičia pradinių mokymo taškų intervalo.

Tiesioginis sklidimas:

```text
H = tanh(W1 * U + b1)
Yhat = W2 * H + b2
```

Pagrindinio tinklo `W1` dydis 8 × 1, `b1` – 8 × 1, `W2` – 1 × 8, `b2` – skaliaras: iš viso 25 parametrai. Papildomame tinkle `W1` yra 8 × 2, iš viso 33 parametrai. Tiesinė išėjimo aktyvacija leidžia prognozuoti ne tik intervalą [-1,1].

**Tikslinė sinuso formulė naudojama mokymo atsakams ir rezultatų palyginimui.** Funkcija `predictMLP` jos nenaudoja: atsaką skaičiuoja iš išmoktų svorių ir `tanh`.

## Paklaida ir atgalinis sklidimas

Minimizuojama vidutinė kvadratinė paklaida:

```text
E = Yhat - Y
MSE = sum(E.^2) / N
```

Pagal grandinės taisyklę gradientai yra:

```text
D2  = 2 * E / N
gW2 = D2 * H'
gb2 = sum(D2, 2)
D1  = (W2' * D2) .* (1 - H.^2)
gW1 = D1 * U'
gb1 = sum(D1, 2)
```

`1-H.^2` yra hiperbolinio tangento išvestinė. Ji parodo, kaip paslėptojo neurono išėjimas keičiasi keičiant jo svertinę sumą. Visi gradientai apskaičiuojami su tais pačiais, dar neatnaujintais svoriais.

Svoriams ir poslinkiams atnaujinti taikomas gradientinis nusileidimas su inercija:

```text
v = 0.9 * v - 0.03 * gradientas
parametras = parametras + v
```

Atgalinis sklidimas apskaičiuoja gradientą, o ši taisyklė pagal jį pakeičia parametrus. Viena epocha apdoroja visą mokymo imtį. Mokymas baigiamas pasiekus MSE ≤ 0.00001 arba 100 000 epochų. `rng(12)` leidžia pakartoti eksperimentą su tais pačiais pradiniais svoriais.

## Rezultatų vertinimas

Gauti rezultatai paleidus MATLAB R2026a su `rng(12)`:

| Užduotis | Epochos | Mokymo MSE | Tankaus tinklelio MSE |
|---|---:|---:|---:|
| Funkcija, 1–8–1 | 27 175 | 9.9994795 × 10⁻⁶ | 8.2154218 × 10⁻⁶ |
| Paviršius, 2–8–1 | 13 521 | 9.9997173 × 10⁻⁶ | 7.9652460 × 10⁻⁶ |

Abiem atvejais pasiekta nustatyta mokymo paklaida nepasiekus epochų ribos. Peržiūrėtuose grafikuose tinklo kreivė ir paviršius artimi tiksliniams; aproksimacija nėra visiškai tiksli. Abi automatinės patikros praėjo, MATLAB procesas baigėsi be klaidos.

- `funkcija.png`: tikslinė kreivė, tinklo kreivė, 20 mokymo taškų ir mokymo MSE kitimas.
- `pavirsius.png`: tikslinis paviršius, tinklo paviršius, absoliuti paklaida ir mokymo MSE kitimas.
- `koeficientai.mat`: abiejų tinklų parametrai, paklaidų istorijos ir galutinės MSE reikšmės.
- Command Window: svoriai, poslinkiai, epochų skaičiai ir MSE.

Funkcija tikrinama tankiame 401 taško tinklelyje, paviršius – 61 × 61 tinklelyje. Tai aproksimavimo patikra tame pačiame intervale; tinkleliai gali turėti bendrų taškų su mokymo imtimi ir nėra visiškai atskira statistinė testavimo imtis. Jų duomenys svoriams atnaujinti nenaudojami. Ekstrapoliacija už [0,1] ribų netirta.

Programa automatiškai patikrina, ar paklaidos baigtinės ir ar abiejų tankių tinklelių MSE < 0.001. Ši riba yra sprendimo patikra, o ne dėstytojo nurodytas vertinimo kriterijus.

## Trumpai atsiskaitymui

1. **Kodėl reikia paslėptojo sluoksnio?** Su netiesine aktyvacija tinklas gali aproksimuoti netiesinę funkciją. Vien tiesinių sluoksnių kompozicija liktų tiesinė.
2. **Kas išmokstama?** Jungčių svoriai ir neuronų poslinkiai, o ne sinuso formulės koeficientai.
3. **Kas yra atgalinis sklidimas?** Paklaidos išvestinių skaičiavimas nuo išėjimo atgal į paslėptąjį sluoksnį pagal grandinės taisyklę.
4. **Kodėl tikrinti tarp mokymo taškų?** Maža mokymo paklaida dar neparodo, ar tinklas gerai atkuria visą kreivę.
5. **Kas keičiasi paviršiaus atveju?** Atsiranda antras įėjimas ir antras `W1` stulpelis; mokymo algoritmo principas nesikeičia.

Tai vykdomas sprendimas ir paaiškinimas; oficialus ataskaitos šablonas, studento duomenys ir papildomi dėstytojo reikalavimai nebuvo pateikti.
