# ND2 eksperimentų paleidimas

Darbas atkartoja M. Dewis ir T. Viana straipsnio „Phish Responder: A Hybrid Machine Learning Approach to Detect Phishing and Spam Emails“ skaitiniams duomenims skirtus MLP bandymus. Naudojamas oficialus UCI `Spambase` rinkinys. Papildomai tikrinamas požymių standartizavimas, paprastesnis MLP `64-32-16` ir SVM su RBF branduoliu.

## Failai

- `run_experiments.py` – visi eksperimentai, rezultatų lentelės ir grafikai.
- `data/` – oficialus UCI `Spambase` rinkinys ir jo aprašas.
- `results/` – faktiniai CSV, JSON, modeliai ir PNG grafikai.
- `report/` – galutinė Word ir PDF ataskaita.
- `ai_log.md` – DI agento naudojimo ir patikros aprašas.

## Paleidimas

Rekomenduojama Python 3.12 aplinka.

```text
python -m venv .venv
.venv\Scripts\activate
python -m pip install -r requirements.txt
python run_experiments.py
```

Trumpas techninis patikrinimas:

```text
python run_experiments.py --quick
```

Visas bandymas naudoja penkias fiksuotas sėklas: 42, 43, 44, 45 ir 46. Kiekvienai sėklai duomenys dalijami santykiu 70/30, išlaikant klasių proporcijas. Viena pagrindinė komanda atlieka ir straipsnio, ir visus papildomus eksperimentus.

## Svarbus atkuriamumo apribojimas

Straipsnio 6 lentelėje nurodyta 6098 `Spambase` mokymo ir testavimo atvejų, nors oficialiame rinkinyje yra 4601 įrašas. Straipsnyje neaprašytas balansavimo ar dubliavimo būdas, atsitiktinė sėkla ir skaitinių požymių mastelio keitimas. Todėl programa naudoja oficialų rinkinį be dirbtinio eilučių dauginimo ir ataskaitoje šį skirtumą aiškiai nurodo.

## Šaltiniai

- Straipsnis: https://doi.org/10.3390/asi5040073
- Duomenys: https://doi.org/10.24432/C53G6X
