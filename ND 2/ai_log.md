# DI agento naudojimo žurnalas

## Atlikti darbai

DI agentas buvo naudojamas straipsnio metodikai išanalizuoti, jo schemose pateiktai MLP sandarai perkelti į programą, eksperimentų kodui parengti, bandymams paleisti, rezultatams patikrinti ir ataskaitos juodraščiui suformuoti.

## Patikrinti pasiūlymai

1. Straipsnio tekstas ir 2, 3, 5 bei 7 paveikslai patikrinti pagal atvirosios prieigos leidėjo PDF. Modelyje palikti du sigmoidiniai išvesties sluoksniai, nes straipsnio 5 lentelėje nurodyta `Output (×2)`.
2. Duomenų eilučių ir požymių skaičius programa tikrina prieš mokymą. Priimami tik 4601 įrašas, 57 požymiai ir klasės 0 bei 1.
3. DI pasiūlytas rezultatas nelaikytas faktiniu, kol programa nebuvo paleista. Ataskaitos skaičiai paimti tik iš išsaugotų CSV ir JSON failų.

## Aptiktos problemos ir atmesti pasiūlymai

1. Iš pradžių buvo galima tiesiog pakartoti straipsnyje nurodytus 2505 + 2505 mokymo ir 544 + 544 testavimo atvejus. Šis pasiūlymas atmestas, nes bendra 6098 suma viršija oficialaus `Spambase` rinkinio 4601 eilutę, o autoriai neaprašo papildomų duomenų gavimo.
2. Buvo galima standartizavimą laikyti straipsnio metodikos dalimi. Tai atmesta, nes straipsnyje jis nenurodytas. Standartizavimas perkeltas į atskirą papildomą eksperimentą.
3. Nebuvo spėjama straipsnyje nepateikta atsitiktinė sėkla. Naudotos aiškiai įvardytos sėklos 42–46, o šis metodinis skirtumas nurodytas ataskaitoje.
