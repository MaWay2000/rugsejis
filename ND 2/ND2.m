%% ND2. Benzino kainos prognozavimas naudojant ANFIS
% Studentas: Mantas Matusevicius
% Grupe: DISfm-26
%
% Atkartojamas straipsnis:
% E. H. I. Eliwa, A. M. El Koshiry, T. Abd El-Hafeez ir A. Omar,
% "Optimal Gasoline Price Predictions: Leveraging the ANFIS Regression
% Model", International Journal of Intelligent Systems, 2024.

clear;
clc;
close all;

rng(42, "twister");

%% 1 etapas. Aplankai ir pradines nuostatos
programosAplankas = fileparts(mfilename("fullpath"));
duomenuFailas = fullfile(programosAplankas, "data", ...
    "EIA_weekly_gasoline_prices.xls");
rezultatuAplankas = fullfile(programosAplankas, "ANFIS_rezultatai");
grafikuAplankas = fullfile(rezultatuAplankas, "grafikai");

if ~isfolder(rezultatuAplankas)
    mkdir(rezultatuAplankas);
end
if ~isfolder(grafikuAplankas)
    mkdir(grafikuAplankas);
end

epochuSkaicius = 100;
narystesFunkcijuSkaicius = 2;
mokymosiGreitis = 0.01;
reguliarizacija = 1e-5;

% Kainos grafikuose ir ateities prognozese pateikiamos EUR uz litra.
% Naudojamas fiksuotas ECB kursas: 1 EUR = 1.1403 USD.
usdUzEura = 1.1403;
litruGalone = 3.785411784;
konversijaIEurUzLitra = 1 / (usdUzEura * litruGalone);

%% 2 etapas. EIA duomenu nuskaitymas
if ~isfile(duomenuFailas)
    error("Nerastas EIA duomenu failas: %s", duomenuFailas);
end

zaliDuomenys = readtable(duomenuFailas, ...
    "Sheet", "Data 1", "VariableNamingRule", "preserve");
visosDatos = zaliDuomenys{:, 1};
visosKainos = zaliDuomenys{:, 2};
galiojanciosEilutes = ~isnat(visosDatos) & ~isnan(visosKainos);
visosDatos = visosDatos(galiojanciosEilutes);
visosKainos = visosKainos(galiojanciosEilutes);
visosKainosEurUzLitra = visosKainos * konversijaIEurUzLitra;

straipsnioPabaiga = datetime(2023, 7, 31);
tinkamosEilutes = visosDatos <= straipsnioPabaiga;
datos = visosDatos(tinkamosEilutes);
kainos = visosKainos(tinkamosEilutes);
kainosEurUzLitra = kainos * konversijaIEurUzLitra;

if numel(kainos) ~= 1583
    error("Tikėtasi 1583 irasu iki 2023-07-31, rasta %d.", numel(kainos));
end

isvedamiDuomenys = table(datos, kainos, ...
    'VariableNames', {'Data', 'Kaina_USD_uz_galona'});
writetable(isvedamiDuomenys, ...
    fullfile(programosAplankas, "data", "EIA_straipsnio_duomenys.csv"));

fprintf("Nuskaityti %d EIA savaitiniai irasai: %s - %s.\n", ...
    numel(kainos), string(datos(1), "yyyy-MM-dd"), ...
    string(datos(end), "yyyy-MM-dd"));

%% 3 etapas. Straipsnyje nurodytos imties paruosimas
% Straipsnis skelbia 1583 irasus, bet jo mokymo ir testavimo imtys sudaro
% tik 1502 irasus (1051 + 451). Kad eksperimentas atitiktu paskelbtus
% dydzius, naudojami pirmieji 1502 chronologiniai EIA irasai, o mokymo ir
% testavimo indeksai sumaisomi su fiksuota atsitiktine seka.
straipsnioImtiesDydis = 1502;
mokymoDydis = 1051;
testavimoDydis = 451;

datosBandymui = datos(1:straipsnioImtiesDydis);
kainosBandymui = kainos(1:straipsnioImtiesDydis);
ankstesneKaina = [kainosBandymui(1); kainosBandymui(1:end-1)];

kalendoriniaiPozymiai = [day(datosBandymui), ...
    month(datosBandymui), year(datosBandymui)];
pozymiaiSuKaina = [kalendoriniaiPozymiai, ankstesneKaina];

indeksai = randperm(straipsnioImtiesDydis);
mokymoIndeksai = indeksai(1:mokymoDydis);
testavimoIndeksai = indeksai(mokymoDydis + 1:end);

if numel(testavimoIndeksai) ~= testavimoDydis
    error("Neteisingas testavimo imties dydis.");
end

%% 4 etapas. Pirmas bandymas be ankstesnes kainos
[X1Mokymas, X1Testas, X1Minimumas, X1Diapazonas] = ...
    normalizuotiPozymius(kalendoriniaiPozymiai(mokymoIndeksai, :), ...
    kalendoriniaiPozymiai(testavimoIndeksai, :));
yMokymas = kainosBandymui(mokymoIndeksai);
yTestas = kainosBandymui(testavimoIndeksai);

fprintf("\n1 bandymas: ANFIS be ankstesnes kainos\n");
modelisBeKainos = mokytiAnfis(X1Mokymas, yMokymas, ...
    narystesFunkcijuSkaicius, epochuSkaicius, ...
    mokymosiGreitis, reguliarizacija);
prognozeBeKainos = prognozuotiAnfis(modelisBeKainos, X1Testas);
rodikliaiBeKainos = skaiciuotiRodiklius(yTestas, prognozeBeKainos);
spausdintiRodiklius(rodikliaiBeKainos);

%% 5 etapas. Antras bandymas su ankstesnes savaites kaina
[X2Mokymas, X2Testas, X2Minimumas, X2Diapazonas] = ...
    normalizuotiPozymius(pozymiaiSuKaina(mokymoIndeksai, :), ...
    pozymiaiSuKaina(testavimoIndeksai, :));

fprintf("\n2 bandymas: ANFIS su ankstesnes savaites kaina\n");
modelisSuKaina = mokytiAnfis(X2Mokymas, yMokymas, ...
    narystesFunkcijuSkaicius, epochuSkaicius, ...
    mokymosiGreitis, reguliarizacija);
prognozeSuKaina = prognozuotiAnfis(modelisSuKaina, X2Testas);
rodikliaiSuKaina = skaiciuotiRodiklius(yTestas, prognozeSuKaina);
spausdintiRodiklius(rodikliaiSuKaina);

%% 6 etapas. Rezultatu palyginimas su straipsniu
modeliai = ["Be ankstesnes kainos"; "Su ankstesne kaina"];
straipsnioMSE = [0.2259; 0.04164];
straipsnioRMSE = [0.2828; 0.0532];
straipsnioR2 = [0.5620; 0.9970];
straipsnioKoreliacija = [0.7496; 0.9985];

atkartotasMSE = [rodikliaiBeKainos.MSE; rodikliaiSuKaina.MSE];
atkartotasRMSE = [rodikliaiBeKainos.RMSE; rodikliaiSuKaina.RMSE];
atkartotasR2 = [rodikliaiBeKainos.R2; rodikliaiSuKaina.R2];
atkartotaKoreliacija = [rodikliaiBeKainos.Koreliacija; ...
    rodikliaiSuKaina.Koreliacija];

rezultatai = table(modeliai, straipsnioMSE, atkartotasMSE, ...
    straipsnioRMSE, atkartotasRMSE, straipsnioR2, atkartotasR2, ...
    straipsnioKoreliacija, atkartotaKoreliacija, ...
    'VariableNames', {'Modelis', 'Straipsnio_MSE', 'Atkartotas_MSE', ...
    'Straipsnio_RMSE', 'Atkartotas_RMSE', 'Straipsnio_R2', ...
    'Atkartotas_R2', 'Straipsnio_koreliacija', ...
    'Atkartota_koreliacija'});
writetable(rezultatai, fullfile(rezultatuAplankas, ...
    "rezultatu_palyginimas.csv"));

testavimoRezultatai = table(datosBandymui(testavimoIndeksai), yTestas, ...
    prognozeBeKainos, prognozeSuKaina, ...
    'VariableNames', {'Data', 'Tikroji_kaina', ...
    'Prognoze_be_ankstesnes_kainos', 'Prognoze_su_ankstesne_kaina'});
testavimoRezultatai = sortrows(testavimoRezultatai, "Data");
writetable(testavimoRezultatai, fullfile(rezultatuAplankas, ...
    "testavimo_prognozes.csv"));

%% 7 etapas. 52 savaiciu ir prognozes iki 2030 metu sudarymas
fprintf("\nPapildomas bandymas: 52 savaiciu kainos prognoze\n");
ankstesneKainaVisaiIstorijai = [visosKainos(1); visosKainos(1:end-1)];
prognozesPozymiai = [day(visosDatos), month(visosDatos), ...
    year(visosDatos), ankstesneKainaVisaiIstorijai];
[normalizuotiPrognozesPozymiai, ~, prognozesMinimumas, ...
    prognozesDiapazonas] = normalizuotiPozymius(prognozesPozymiai, ...
    prognozesPozymiai);
modelisMetuPrognozei = mokytiAnfis(normalizuotiPrognozesPozymiai, ...
    visosKainos, narystesFunkcijuSkaicius, epochuSkaicius, ...
    mokymosiGreitis, reguliarizacija);

ateitiesDatos = (visosDatos(end) + calweeks(1):calweeks(1): ...
    visosDatos(end) + calweeks(52))';
metuPrognoze = zeros(numel(ateitiesDatos), 1);
ankstesnePrognoze = visosKainos(end);
for savaite = 1:numel(ateitiesDatos)
    naujiPozymiai = [day(ateitiesDatos(savaite)), ...
        month(ateitiesDatos(savaite)), year(ateitiesDatos(savaite)), ...
        ankstesnePrognoze];
    normalizuotiPozymiai = (naujiPozymiai - prognozesMinimumas) ./ ...
        prognozesDiapazonas;
    metuPrognoze(savaite) = prognozuotiAnfis(modelisMetuPrognozei, ...
        normalizuotiPozymiai);
    ankstesnePrognoze = metuPrognoze(savaite);
end
metuPrognozeEurUzLitra = metuPrognoze * konversijaIEurUzLitra;
metuPrognozesLentele = table(ateitiesDatos, metuPrognozeEurUzLitra, ...
    'VariableNames', {'Data', 'Prognozuota_kaina_EUR_uz_litra'});
writetable(metuPrognozesLentele, fullfile(rezultatuAplankas, ...
    "metu_prognoze.csv"));

figuraAteitis = figure("Visible", "off", "Color", "w", ...
    "Position", [100 100 1200 620]);
plot(visosDatos, visosKainosEurUzLitra, "k-", "LineWidth", 1.2);
hold on;
plot([visosDatos(end); ateitiesDatos], ...
    [visosKainosEurUzLitra(end); metuPrognozeEurUzLitra], ...
    "-", "Color", [0.00 0.45 0.74], "LineWidth", 1.8);
xline(visosDatos(end), ":", "Prognozes pradzia", ...
    "HandleVisibility", "off");
grid on;
xlabel("Data");
ylabel("Kaina, EUR už litrą");
title("Reali benzino kaina ir 52 savaičių ANFIS prognozė");
legend("Reali buvusi kaina", "52 savaičių prognozė", ...
    "Location", "best");
exportgraphics(figuraAteitis, fullfile(grafikuAplankas, ...
    "reali_kaina_ir_52_savaiciu_prognoze.png"), "Resolution", 180);
close(figuraAteitis);

rodomosEilutes = visosDatos >= visosDatos(end) - calyears(3);
figuraAteitis2 = figure("Visible", "off", "Color", "w", ...
    "Position", [100 100 1200 620]);
tikrosLinija = plot(visosDatos(rodomosEilutes), ...
    visosKainosEurUzLitra(rodomosEilutes), "Color", [0.10 0.34 0.58], ...
    "LineWidth", 1.5);
hold on;
prognozesLinija = plot([visosDatos(end); ateitiesDatos], ...
    [visosKainosEurUzLitra(end); metuPrognozeEurUzLitra], "--o", ...
    "Color", [0.90 0.35 0.08], "LineWidth", 1.8, "MarkerSize", 3);
xline(visosDatos(end), ":", "Prognozes pradzia", ...
    "HandleVisibility", "off");
grid on;
xlabel("Data");
ylabel("Kaina, EUR už litrą");
title("Paskutiniai 3 metai ir vienų metų kainos prognozė");
legend([tikrosLinija, prognozesLinija], ...
    "Reali buvusi kaina", "52 savaičių prognozė", ...
    "Location", "best");
exportgraphics(figuraAteitis2, fullfile(grafikuAplankas, ...
    "paskutiniai_3_metai_ir_metu_prognoze.png"), "Resolution", 180);
close(figuraAteitis2);

fprintf("Paskutine reali kaina: %.3f EUR/l (%s)\n", ...
    visosKainosEurUzLitra(end), string(visosDatos(end), "yyyy-MM-dd"));
fprintf("Metu prognoze: %.3f-%.3f EUR/l\n", ...
    min(metuPrognozeEurUzLitra), max(metuPrognozeEurUzLitra));

% Ilgo laikotarpio prognoze naudojama rezultatui iliustruoti. Didejant
% horizontui rekursines prognozes neapibreztumas taip pat dideja.
pabaigosData2030 = datetime(2030, 12, 31);
datosIki2030 = (visosDatos(end) + calweeks(1):calweeks(1): ...
    pabaigosData2030)';
prognozeIki2030 = zeros(numel(datosIki2030), 1);
ankstesnePrognoze2030 = visosKainos(end);
for savaite = 1:numel(datosIki2030)
    naujiPozymiai2030 = [day(datosIki2030(savaite)), ...
        month(datosIki2030(savaite)), year(datosIki2030(savaite)), ...
        ankstesnePrognoze2030];
    normalizuotiPozymiai2030 = (naujiPozymiai2030 - ...
        prognozesMinimumas) ./ prognozesDiapazonas;
    prognozeIki2030(savaite) = prognozuotiAnfis( ...
        modelisMetuPrognozei, normalizuotiPozymiai2030);
    ankstesnePrognoze2030 = prognozeIki2030(savaite);
end
prognozeIki2030EurUzLitra = prognozeIki2030 * konversijaIEurUzLitra;
prognozeIki2030Lentele = table(datosIki2030, ...
    prognozeIki2030EurUzLitra, 'VariableNames', ...
    {'Data', 'Prognozuota_kaina_EUR_uz_litra'});
writetable(prognozeIki2030Lentele, fullfile(rezultatuAplankas, ...
    "prognoze_iki_2030.csv"));

figura2030 = figure("Visible", "off", "Color", "w", ...
    "Position", [100 100 1200 620]);
plot(visosDatos, visosKainosEurUzLitra, "k-", "LineWidth", 1.2);
hold on;
plot([visosDatos(end); datosIki2030], ...
    [visosKainosEurUzLitra(end); prognozeIki2030EurUzLitra], ...
    "-", "Color", [0.00 0.45 0.74], "LineWidth", 1.8);
xline(visosDatos(end), ":", "Prognozes pradzia", ...
    "HandleVisibility", "off");
grid on;
xlabel("Data");
ylabel("Kaina, EUR už litrą");
title("Tikroji kaina ir ANFIS prognozė iki 2030 m.");
legend("Tikroji kaina", "Prognozė iki 2030 m.", "Location", "best");
xlim([visosDatos(1), pabaigosData2030]);
exportgraphics(figura2030, fullfile(grafikuAplankas, ...
    "tikroji_kaina_ir_prognoze_iki_2030.png"), "Resolution", 180);
close(figura2030);
fprintf("Prognoze iki 2030 m.: %.3f-%.3f EUR/l\n", ...
    min(prognozeIki2030EurUzLitra), max(prognozeIki2030EurUzLitra));

%% 8 etapas. Grafiku sudarymas
figura1 = figure("Visible", "off", "Color", "w");
plot(datos, kainosEurUzLitra, "Color", [0.12 0.36 0.58], ...
    "LineWidth", 1.0);
grid on;
xlabel("Data");
ylabel("Kaina, EUR už litrą");
title("Savaitinė JAV benzino kaina");
exportgraphics(figura1, fullfile(grafikuAplankas, ...
    "benzino_kainu_laiko_eilute.png"), "Resolution", 180);
close(figura1);

figura2 = figure("Visible", "off", "Color", "w");
plot(testavimoRezultatai.Data, ...
    testavimoRezultatai.Tikroji_kaina * konversijaIEurUzLitra, ...
    "k-", "LineWidth", 1.2);
hold on;
plot(testavimoRezultatai.Data, ...
    testavimoRezultatai.Prognoze_be_ankstesnes_kainos * ...
    konversijaIEurUzLitra, ...
    "--", "Color", [0.85 0.33 0.10], "LineWidth", 1.0);
plot(testavimoRezultatai.Data, ...
    testavimoRezultatai.Prognoze_su_ankstesne_kaina * ...
    konversijaIEurUzLitra, ...
    "-", "Color", [0.00 0.45 0.74], "LineWidth", 1.0);
grid on;
xlabel("Data");
ylabel("Kaina, EUR už litrą");
title("Tikrosios ir ANFIS prognozuotos kainos");
legend("Tikroji kaina", "Be ankstesnes kainos", ...
    "Su ankstesne kaina", "Location", "best");
exportgraphics(figura2, fullfile(grafikuAplankas, ...
    "tikrosios_ir_prognozuotos_kainos.png"), "Resolution", 180);
close(figura2);

figura3 = figure("Visible", "off", "Color", "w");
semilogy(modelisBeKainos.MokymoKlaida, "LineWidth", 1.3);
hold on;
semilogy(modelisSuKaina.MokymoKlaida, "LineWidth", 1.3);
grid on;
xlabel("Epocha");
ylabel("MSE");
title("ANFIS mokymo klaida");
legend("Be ankstesnes kainos", "Su ankstesne kaina", ...
    "Location", "best");
exportgraphics(figura3, fullfile(grafikuAplankas, ...
    "mokymo_klaida.png"), "Resolution", 180);
close(figura3);

figura4 = figure("Visible", "off", "Color", "w");
pozYmes = ["Diena", "Mėnuo", "Metai", "Ankstesnė kaina"];
for j = 1:size(modelisSuKaina.Centrai, 1)
    subplot(2, 2, j);
    x = linspace(0, 1, 300)';
    hold on;
    for m = 1:narystesFunkcijuSkaicius
        y = exp(-0.5 * ((x - modelisSuKaina.Centrai(j, m)) ./ ...
            modelisSuKaina.Sigmos(j, m)).^2);
        plot(x, y, "LineWidth", 1.4);
    end
    grid on;
    title(pozYmes(j));
    xlabel("Normalizuota reikšmė");
    ylabel("Narystes laipsnis");
end
sgtitle("Išmoktos Gauso narystės funkcijos");
exportgraphics(figura4, fullfile(grafikuAplankas, ...
    "narystes_funkcijos.png"), "Resolution", 180);
close(figura4);

%% 9 etapas. Modeliu ir aplinkos issaugojimas
save(fullfile(rezultatuAplankas, "anfis_modeliai.mat"), ...
    "modelisBeKainos", "modelisSuKaina", "modelisMetuPrognozei", ...
    "X1Minimumas", "X1Diapazonas", "X2Minimumas", "X2Diapazonas", ...
    "prognozesMinimumas", "prognozesDiapazonas", ...
    "mokymoIndeksai", "testavimoIndeksai", ...
    "usdUzEura", "litruGalone", "konversijaIEurUzLitra");

aplinka = table(string(version), string(computer), ...
    feature("numcores"), epochuSkaicius, narystesFunkcijuSkaicius, ...
    'VariableNames', {'MATLAB', 'Platforma', 'Branduoliai', ...
    'Epochos', 'Narystes_funkcijos_vienam_pozymiui'});
writetable(aplinka, fullfile(rezultatuAplankas, "aplinka.csv"));

disp(" ");
disp("Galutinis rezultatu palyginimas:");
disp(rezultatai);
fprintf("Rezultatai issaugoti: %s\n", rezultatuAplankas);

%% Vietines funkcijos
function [mokymas, testas, minimumas, diapazonas] = ...
        normalizuotiPozymius(mokymoPozymiai, testavimoPozymiai)
    minimumas = min(mokymoPozymiai, [], 1);
    maksimumas = max(mokymoPozymiai, [], 1);
    diapazonas = maksimumas - minimumas;
    diapazonas(diapazonas == 0) = 1;
    mokymas = (mokymoPozymiai - minimumas) ./ diapazonas;
    testas = (testavimoPozymiai - minimumas) ./ diapazonas;
end

function modelis = mokytiAnfis(X, y, mfSkaicius, epochos, ...
        mokymosiGreitis, reguliarizacija)
    [eiluciuSkaicius, pozymiuSkaicius] = size(X);
    taisykles = dec2bin(0:(mfSkaicius^pozymiuSkaicius - 1), ...
        pozymiuSkaicius) - '0' + 1;
    centrai = zeros(pozymiuSkaicius, mfSkaicius);
    sigmos = zeros(pozymiuSkaicius, mfSkaicius);
    for j = 1:pozymiuSkaicius
        surikiuota = sort(X(:, j));
        vietos = round(linspace(0.30, 0.70, mfSkaicius) * ...
            (eiluciuSkaicius - 1)) + 1;
        centrai(j, :) = surikiuota(vietos);
        sigmos(j, :) = max(0.20, ...
            (max(X(:, j)) - min(X(:, j))) / (mfSkaicius + 0.5));
    end
    logSigmos = log(sigmos);

    pirmasMomentas = zeros(size(centrai, 1), size(centrai, 2), 2);
    antrasMomentas = zeros(size(centrai, 1), size(centrai, 2), 2);
    beta1 = 0.9;
    beta2 = 0.999;
    adamEpsilon = 1e-8;
    mokymoKlaida = zeros(epochos, 1);

    for epocha = 1:epochos
        sigmos = exp(logSigmos);
        svoriai = skaiciuotiSvorius(X, centrai, ...
            sigmos, taisykles, mfSkaicius);
        [~, taisykliuIsvestys, prognoze] = ...
            rastiKonsekventus(X, y, svoriai, reguliarizacija);
        klaida = prognoze - y;
        mokymoKlaida(epocha) = mean(klaida.^2);

        centruGradientas = zeros(size(centrai));
        sigmuGradientas = zeros(size(sigmos));
        for j = 1:pozymiuSkaicius
            for m = 1:mfSkaicius
                susijusios = taisykles(:, j) == m;
                itaka = sum(svoriai(:, susijusios) .* ...
                    (taisykliuIsvestys(:, susijusios) - prognoze), 2);
                centroDaugiklis = (X(:, j) - centrai(j, m)) ./ ...
                    (sigmos(j, m)^2);
                sigmosDaugiklis = ((X(:, j) - centrai(j, m)) ./ ...
                    sigmos(j, m)).^2;
                centruGradientas(j, m) = (2 / eiluciuSkaicius) * ...
                    sum(klaida .* itaka .* centroDaugiklis);
                sigmuGradientas(j, m) = (2 / eiluciuSkaicius) * ...
                    sum(klaida .* itaka .* sigmosDaugiklis);
            end
        end

        [centrai, pirmasMomentas(:, :, 1), antrasMomentas(:, :, 1)] = ...
            adamZingsnis(centrai, centruGradientas, ...
            pirmasMomentas(:, :, 1), antrasMomentas(:, :, 1), ...
            epocha, mokymosiGreitis, beta1, beta2, adamEpsilon);
        [logSigmos, pirmasMomentas(:, :, 2), antrasMomentas(:, :, 2)] = ...
            adamZingsnis(logSigmos, sigmuGradientas, ...
            pirmasMomentas(:, :, 2), antrasMomentas(:, :, 2), ...
            epocha, mokymosiGreitis, beta1, beta2, adamEpsilon);

        centrai = min(max(centrai, -0.25), 1.25);
        logSigmos = min(max(logSigmos, log(0.07)), log(1.25));

        if epocha == 1 || mod(epocha, 20) == 0 || epocha == epochos
            fprintf("  Epocha %3d/%d, mokymo MSE %.6f\n", ...
                epocha, epochos, mokymoKlaida(epocha));
        end
    end

    sigmos = exp(logSigmos);
    svoriai = skaiciuotiSvorius(X, centrai, sigmos, ...
        taisykles, mfSkaicius);
    [koeficientai, ~, ~] = rastiKonsekventus(X, y, svoriai, ...
        reguliarizacija);

    modelis.Centrai = centrai;
    modelis.Sigmos = sigmos;
    modelis.Taisykles = taisykles;
    modelis.Koeficientai = koeficientai;
    modelis.MokymoKlaida = mokymoKlaida;
    modelis.NarystesFunkcijuSkaicius = mfSkaicius;
end

function prognoze = prognozuotiAnfis(modelis, X)
    svoriai = skaiciuotiSvorius(X, modelis.Centrai, ...
        modelis.Sigmos, modelis.Taisykles, ...
        modelis.NarystesFunkcijuSkaicius);
    papildytiPozymiai = [X, ones(size(X, 1), 1)];
    taisykliuIsvestys = papildytiPozymiai * modelis.Koeficientai;
    prognoze = sum(svoriai .* taisykliuIsvestys, 2);
end

function [normalizuotiSvoriai, narystes] = skaiciuotiSvorius( ...
        X, centrai, sigmos, taisykles, mfSkaicius)
    [eiluciuSkaicius, pozymiuSkaicius] = size(X);
    taisykliuSkaicius = size(taisykles, 1);
    narystes = zeros(eiluciuSkaicius, pozymiuSkaicius, mfSkaicius);
    for j = 1:pozymiuSkaicius
        for m = 1:mfSkaicius
            narystes(:, j, m) = exp(-0.5 * ...
                ((X(:, j) - centrai(j, m)) ./ sigmos(j, m)).^2);
        end
    end

    svoriai = ones(eiluciuSkaicius, taisykliuSkaicius);
    for r = 1:taisykliuSkaicius
        for j = 1:pozymiuSkaicius
            svoriai(:, r) = svoriai(:, r) .* ...
                narystes(:, j, taisykles(r, j));
        end
    end
    normalizuotiSvoriai = svoriai ./ ...
        max(sum(svoriai, 2), realmin("double"));
end

function [koeficientai, taisykliuIsvestys, prognoze] = ...
        rastiKonsekventus(X, y, svoriai, reguliarizacija)
    [eiluciuSkaicius, pozymiuSkaicius] = size(X);
    taisykliuSkaicius = size(svoriai, 2);
    papildytiPozymiai = [X, ones(eiluciuSkaicius, 1)];
    matrica = zeros(eiluciuSkaicius, ...
        taisykliuSkaicius * (pozymiuSkaicius + 1));
    for r = 1:taisykliuSkaicius
        stulpeliai = (r - 1) * (pozymiuSkaicius + 1) + ...
            (1:(pozymiuSkaicius + 1));
        matrica(:, stulpeliai) = svoriai(:, r) .* papildytiPozymiai;
    end
    vienetine = eye(size(matrica, 2));
    parametrai = (matrica' * matrica + reguliarizacija * vienetine) \ ...
        (matrica' * y);
    koeficientai = reshape(parametrai, pozymiuSkaicius + 1, ...
        taisykliuSkaicius);
    taisykliuIsvestys = papildytiPozymiai * koeficientai;
    prognoze = sum(svoriai .* taisykliuIsvestys, 2);
end

function [parametrai, pirmasMomentas, antrasMomentas] = adamZingsnis( ...
        parametrai, gradientas, pirmasMomentas, antrasMomentas, ...
        zingsnis, greitis, beta1, beta2, epsilon)
    pirmasMomentas = beta1 * pirmasMomentas + ...
        (1 - beta1) * gradientas;
    antrasMomentas = beta2 * antrasMomentas + ...
        (1 - beta2) * (gradientas.^2);
    pataisytasPirmas = pirmasMomentas / (1 - beta1^zingsnis);
    pataisytasAntras = antrasMomentas / (1 - beta2^zingsnis);
    parametrai = parametrai - greitis * pataisytasPirmas ./ ...
        (sqrt(pataisytasAntras) + epsilon);
end

function rodikliai = skaiciuotiRodiklius(tikros, prognozuotos)
    liekanos = tikros - prognozuotos;
    rodikliai.MSE = mean(liekanos.^2);
    rodikliai.RMSE = sqrt(rodikliai.MSE);
    rodikliai.MAE = mean(abs(liekanos));
    rodikliai.R2 = 1 - sum(liekanos.^2) / ...
        sum((tikros - mean(tikros)).^2);
    koreliacijosMatrica = corrcoef(tikros, prognozuotos);
    rodikliai.Koreliacija = koreliacijosMatrica(1, 2);
end

function spausdintiRodiklius(rodikliai)
    fprintf("  MSE:         %.6f\n", rodikliai.MSE);
    fprintf("  RMSE:        %.6f\n", rodikliai.RMSE);
    fprintf("  MAE:         %.6f\n", rodikliai.MAE);
    fprintf("  R2:          %.6f\n", rodikliai.R2);
    fprintf("  Koreliacija: %.6f\n", rodikliai.Koreliacija);
end
