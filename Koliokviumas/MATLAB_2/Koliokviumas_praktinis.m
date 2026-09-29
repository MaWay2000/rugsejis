%% KOLIOKVIUMO PRAKTINIS DARBAS
% Nepageidaujamu laisku atpazinimas naudojant UCI Spambase duomenis.
% Mantas Matusevicius, DISfm-26
%
% Programa igyvendina duomenu patikra, grupini 60/20/20 skaidyma,
% vidine 3 daliu grupine patikra ir pilna hiperparametru paieska.
% Testavimo imtis naudojama tik po modeliu ismokymo ir slenksciu parinkimo.

clear;
clc;
close all;
rng(42, "twister");

%% 1 etapas. Aplinkos ir aplanku paruosimas

pradineReiksme = 42;
duomenuNuoroda = "https://archive.ics.uci.edu/static/public/94/spambase.zip";

programosFailas = mfilename("fullpath");
if strlength(programosFailas) == 0
    darboAplankas = pwd;
else
    darboAplankas = fileparts(programosFailas);
end

duomenuAplankas = fullfile(darboAplankas, "duomenys");
rezultatuAplankas = fullfile(darboAplankas, "Koliokviumo_rezultatai");
modeliuAplankas = fullfile(rezultatuAplankas, "modeliai");
grafikuAplankas = fullfile(rezultatuAplankas, "grafikai");

aplankai = {duomenuAplankas, rezultatuAplankas, modeliuAplankas, grafikuAplankas};
for i = 1:numel(aplankai)
    if ~isfolder(aplankai{i})
        mkdir(aplankai{i});
    end
end

fprintf("Koliokviumo praktinis darbas\n");
fprintf("Rezultatai bus saugomi: %s\n\n", rezultatuAplankas);

%% 2 etapas. Duomenu gavimas ir patikra

zipFailas = fullfile(duomenuAplankas, "spambase.zip");
duomenuFailas = fullfile(duomenuAplankas, "spambase.data");
pavadinimuFailas = fullfile(duomenuAplankas, "spambase.names");

if ~isfile(duomenuFailas) || ~isfile(pavadinimuFailas)
    fprintf("Atsisiunciami UCI Spambase duomenys...\n");
    websave(zipFailas, duomenuNuoroda);
    unzip(zipFailas, duomenuAplankas);
end

visiDuomenys = readmatrix(duomenuFailas, "FileType", "text");
if ~isequal(size(visiDuomenys), [4601, 58])
    error("Tiketi 4601 irasai ir 58 stulpeliai, gauta %d x %d.", ...
        size(visiDuomenys, 1), size(visiDuomenys, 2));
end

X = visiDuomenys(:, 1:57);
y = visiDuomenys(:, 58);
if any(~isfinite(X), "all") || any(~isfinite(y))
    error("Duomenyse aptikta trukstamu arba begaliniu reiksmiu.");
end
if ~isequal(unique(y), [0; 1])
    error("Klases turi buti koduojamos 0 ir 1.");
end

pozymiuPavadinimai = nuskaitytiPozymiuPavadinimus(pavadinimuFailas);
if numel(pozymiuPavadinimai) ~= 57
    error("Tiketi 57 pozymiu pavadinimai, gauta %d.", numel(pozymiuPavadinimai));
end

eilutesId = (0:size(X, 1)-1)';
rawFailas = fullfile(duomenuAplankas, "raw.csv");
irasytRawCsv(rawFailas, eilutesId, X, y, pozymiuPavadinimai);

schema = struct;
schema.pozymiai = cellstr(pozymiuPavadinimai);
schema.target = "target";
schema.klases = struct("teisingas_laiskas", 0, "brukalas", 1);
schema.saltinis = duomenuNuoroda;
irasytiJson(fullfile(duomenuAplankas, "schema.json"), schema);

manifestas = struct;
manifestas.saltinis = duomenuNuoroda;
manifestas.irasu_skaicius = size(X, 1);
manifestas.pozymiu_skaicius = size(X, 2);
manifestas.klase_0 = sum(y == 0);
manifestas.klase_1 = sum(y == 1);
manifestas.raw_sha256 = failoSha256(rawFailas);
duomenuInformacija = dir(duomenuFailas);
manifestas.atsisiuntimo_laikas = string(duomenuInformacija.date);
irasytiJson(fullfile(duomenuAplankas, "manifest.json"), manifestas);

fprintf("Duomenys patikrinti: %d irasai, %d pozymiai.\n", size(X, 1), size(X, 2));

%% 3 etapas. Vienodu irasu grupes ir 60/20/20 skaidymas

[~, pirmosEilutes, grupesNumeris] = unique(X, "rows", "first");
grupesId = pirmosEilutes(grupesNumeris) - 1;
unikaliosGrupes = unique(grupesId, "stable");
grupiuKlases = zeros(numel(unikaliosGrupes), 1);

for i = 1:numel(unikaliosGrupes)
    grupesY = y(grupesId == unikaliosGrupes(i));
    grupiuKlases(i) = mode(grupesY);
end

rng(pradineReiksme, "twister");
grupiuSkaidymas = cvpartition(grupiuKlases, "KFold", 5);
daliesNumerisGrupei = zeros(numel(unikaliosGrupes), 1);
for dalis = 1:5
    daliesNumerisGrupei(test(grupiuSkaidymas, dalis)) = dalis - 1;
end

[~, grupesVieta] = ismember(grupesId, unikaliosGrupes);
daliesNumeris = daliesNumerisGrupei(grupesVieta);
testoIndeksai = daliesNumeris == 0;
derinimoIndeksai = daliesNumeris == 1;
mokymoIndeksai = daliesNumeris >= 2;

patikrintiSkaidyma(y, grupesId, mokymoIndeksai, derinimoIndeksai, testoIndeksai);

skaidymoLentele = table(eilutesId, grupesId, daliesNumeris, ...
    strings(size(y)), 'VariableNames', ...
    {'row_id', 'group_id', 'fold', 'split'});
skaidymoLentele.split(mokymoIndeksai) = "train";
skaidymoLentele.split(derinimoIndeksai) = "validation";
skaidymoLentele.split(testoIndeksai) = "test";
writetable(skaidymoLentele, fullfile(duomenuAplankas, "splits.csv"));

fprintf("Mokymo irasai: %d, derinimo: %d, testavimo: %d.\n", ...
    sum(mokymoIndeksai), sum(derinimoIndeksai), sum(testoIndeksai));

%% 4 etapas. Vidine grupine patikra ir hiperparametru paieska

Xmok = X(mokymoIndeksai, :);
ymok = y(mokymoIndeksai);
Xder = X(derinimoIndeksai, :);
yder = y(derinimoIndeksai);
mokymoGrupes = grupesId(mokymoIndeksai);

vidiniuDaliuSkaicius = 3;
vidinesDalys = sudarytiVidinesDalis(ymok, mokymoGrupes, ...
    vidiniuDaliuSkaicius, pradineReiksme);

vidiniuDaliuLentele = table(eilutesId(mokymoIndeksai), mokymoGrupes, vidinesDalys, ...
    'VariableNames', {'row_id', 'group_id', 'cv_fold'});
writetable(vidiniuDaliuLentele, fullfile(duomenuAplankas, "vidines_dalys.csv"));

cvEilutes = repmat(tusciaCvEilute(), 0, 1);
bandymoId = 0;

lambdaReiksmes = [0.0001, 0.001, 0.01];
for lambda = lambdaReiksmes
    bandymoId = bandymoId + 1;
    parametrai = struct("Lambda", lambda);
    cvEilutes(end + 1, 1) = vertintiDerini(Xmok, ymok, vidinesDalys, ...
        "Logistine regresija", "lr", parametrai, bandymoId, pradineReiksme); %#ok<SAGROW>
end

cReiksmes = [0.1, 1, 10, 100];
gammaReiksmes = [0.001, 0.01, 0.1];
for c = cReiksmes
    for gamma = gammaReiksmes
        bandymoId = bandymoId + 1;
        parametrai = struct("C", c, "Gamma", gamma);
        cvEilutes(end + 1, 1) = vertintiDerini(Xmok, ymok, vidinesDalys, ...
            "SVM", "svm", parametrai, bandymoId, pradineReiksme); %#ok<SAGROW>
    end
end

medziuReiksmes = [100, 300];
lapoReiksmes = [1, 3];
for medziai = medziuReiksmes
    for lapas = lapoReiksmes
        bandymoId = bandymoId + 1;
        parametrai = struct("Medziai", medziai, "Lapas", lapas);
        cvEilutes(end + 1, 1) = vertintiDerini(Xmok, ymok, vidinesDalys, ...
            "Atsitiktinis miskas", "rf", parametrai, bandymoId, pradineReiksme); %#ok<SAGROW>
    end
end

thetaReiksmes = [0.02, 0.04, 0.08, 0.12];
for medziai = medziuReiksmes
    for lapas = lapoReiksmes
        for theta = thetaReiksmes
            bandymoId = bandymoId + 1;
            parametrai = struct("Medziai", medziai, "Lapas", lapas, "Theta", theta);
            cvEilutes(end + 1, 1) = vertintiDerini(Xmok, ymok, vidinesDalys, ...
                "HCVR-RF", "hcvr_rf", parametrai, bandymoId, pradineReiksme); %#ok<SAGROW>
        end
    end
end

cvRezultatai = struct2table(cvEilutes);
writetable(cvRezultatai, fullfile(rezultatuAplankas, "cv_results.csv"));

geriausiaLr = parinktiGeriausiaDerini(cvRezultatai, "Logistine regresija");
geriausiasSvm = parinktiGeriausiaDerini(cvRezultatai, "SVM");
geriausiasRf = parinktiGeriausiaDerini(cvRezultatai, "Atsitiktinis miskas");
geriausiasHcvr = parinktiGeriausiaDerini(cvRezultatai, "HCVR-RF");

%% 4A etapas. Modifikacijos ir abliacija be 3 didziuju raidziu pozymiu

XmokBeDidziuju = Xmok(:, 1:end-3);
abliacijosEilutes = repmat(tusciaCvEilute(), 0, 1);
abliacijosId = 0;

for medziai = medziuReiksmes
    for lapas = lapoReiksmes
        abliacijosId = abliacijosId + 1;
        parametrai = struct("Medziai", medziai, "Lapas", lapas);
        abliacijosEilutes(end + 1, 1) = vertintiDerini(XmokBeDidziuju, ymok, ...
            vidinesDalys, "RF be didziuju", "rf", parametrai, ...
            abliacijosId, pradineReiksme, "ABL", 20); %#ok<SAGROW>
    end
end

for medziai = medziuReiksmes
    for lapas = lapoReiksmes
        for theta = thetaReiksmes
            abliacijosId = abliacijosId + 1;
            parametrai = struct("Medziai", medziai, "Lapas", lapas, "Theta", theta);
            abliacijosEilutes(end + 1, 1) = vertintiDerini(XmokBeDidziuju, ymok, ...
                vidinesDalys, "HCVR-RF be didziuju", "hcvr_rf", parametrai, ...
                abliacijosId, pradineReiksme, "ABL", 20); %#ok<SAGROW>
        end
    end
end

abliacijosCv = struct2table(abliacijosEilutes);
writetable(abliacijosCv, fullfile(rezultatuAplankas, "cv_ablation_no_capitals.csv"));
geriausiasRfBeDidziuju = parinktiGeriausiaDerini(abliacijosCv, "RF be didziuju");
geriausiasHcvrBeDidziuju = parinktiGeriausiaDerini(abliacijosCv, "HCVR-RF be didziuju");

lrParametrai = struct("Lambda", geriausiaLr.Lambda);
svmParametrai = struct("C", geriausiasSvm.C, "Gamma", geriausiasSvm.Gamma);
rfParametrai = struct("Medziai", geriausiasRf.Medziai, "Lapas", geriausiasRf.Lapas);
hcvrParametrai = struct("Medziai", geriausiasHcvr.Medziai, ...
    "Lapas", geriausiasHcvr.Lapas, "Theta", geriausiasHcvr.Theta);

konfiguracija = struct;
konfiguracija.pradine_reiksme = pradineReiksme;
konfiguracija.vidiniu_daliu_skaicius = vidiniuDaliuSkaicius;
konfiguracija.mokymo_eiluciu = sum(mokymoIndeksai);
konfiguracija.derinimo_eiluciu = sum(derinimoIndeksai);
konfiguracija.testavimo_eiluciu = sum(testoIndeksai);
konfiguracija.atrankos_metrika = "vidutinis PR-AUC";
konfiguracija.lygiuju_taisykle = ...
    "Jei skirtumas iki 0.001: maziau pozymiu, trumpesnis laikas, pirmesnis derinys";
konfiguracija.logistine_regresija = pasirinkimoAprasas(geriausiaLr, lrParametrai);
konfiguracija.svm = pasirinkimoAprasas(geriausiasSvm, svmParametrai);
konfiguracija.atsitiktinis_miskas = pasirinkimoAprasas(geriausiasRf, rfParametrai);
konfiguracija.hcvr_rf = pasirinkimoAprasas(geriausiasHcvr, hcvrParametrai);
konfiguracija.rf_be_didziuju = pasirinkimoAprasas(geriausiasRfBeDidziuju, ...
    struct("Medziai", geriausiasRfBeDidziuju.Medziai, ...
    "Lapas", geriausiasRfBeDidziuju.Lapas));
konfiguracija.hcvr_rf_be_didziuju = pasirinkimoAprasas(geriausiasHcvrBeDidziuju, ...
    struct("Medziai", geriausiasHcvrBeDidziuju.Medziai, ...
    "Lapas", geriausiasHcvrBeDidziuju.Lapas, ...
    "Theta", geriausiasHcvrBeDidziuju.Theta));
konfiguracija.numatytas_mokymu_skaicius = 176;
irasytiJson(fullfile(rezultatuAplankas, "config.json"), konfiguracija);

configKontrolineSumaPriesTesta = failoSha256(fullfile(rezultatuAplankas, "config.json"));

pakeitimai = sukurtiPakeitimuLentele(cvRezultatai, ...
    geriausiaLr, geriausiasSvm, geriausiasRf, geriausiasHcvr, ...
    geriausiasRfBeDidziuju, geriausiasHcvrBeDidziuju);
writetable(pakeitimai, fullfile(rezultatuAplankas, "changes.csv"));

irasytiFitIndeksus(fullfile(rezultatuAplankas, "fit_indeksai.csv"), ...
    eilutesId(mokymoIndeksai), vidinesDalys, height(cvRezultatai), height(abliacijosCv));

fprintf("\nPatikrinti %d hiperparametru deriniai.\n", height(cvRezultatai));
disp(cvRezultatai(ismember(cvRezultatai.bandymo_id, ...
    [geriausiaLr.bandymo_id, geriausiasSvm.bandymo_id, ...
    geriausiasRf.bandymo_id, geriausiasHcvr.bandymo_id]), ...
    {'modelis', 'Lambda', 'C', 'Gamma', 'Medziai', 'Lapas', 'Theta', ...
    'vidutinis_pr_auc', 'pozymiu_skaicius', 'mokymo_laikas_s'}));

%% 5 etapas. Pasirinktu modeliu mokymas ir slenksciu parinkimas

modeliuPavadinimai = ["Daugumos klase", "Logistine regresija", ...
    "SVM", "Atsitiktinis miskas", "HCVR-RF"];
modeliuVersijos = ["majority_42_full", "lr_42_cv", "svm_42_cv", ...
    "rf_42_cv", "hcvr_rf_42_cv"];

paketai = cell(numel(modeliuPavadinimai), 1);
derinimoBalai = cell(numel(modeliuPavadinimai), 1);
mokymoLaikai = zeros(numel(modeliuPavadinimai), 1);

laikmatis = tic;
paketai{1} = mokytiDaugumosModeli(ymok, modeliuVersijos(1));
mokymoLaikai(1) = toc(laikmatis);

laikmatis = tic;
paketai{2} = mokytiModeli(Xmok, ymok, "lr", lrParametrai, ...
    modeliuVersijos(2), pradineReiksme);
mokymoLaikai(2) = toc(laikmatis);

laikmatis = tic;
paketai{3} = mokytiModeli(Xmok, ymok, "svm", svmParametrai, ...
    modeliuVersijos(3), pradineReiksme);
mokymoLaikai(3) = toc(laikmatis);

laikmatis = tic;
paketai{4} = mokytiModeli(Xmok, ymok, "rf", rfParametrai, ...
    modeliuVersijos(4), pradineReiksme);
mokymoLaikai(4) = toc(laikmatis);

laikmatis = tic;
paketai{5} = mokytiModeli(Xmok, ymok, "hcvr_rf", hcvrParametrai, ...
    modeliuVersijos(5), pradineReiksme);
mokymoLaikai(5) = toc(laikmatis);

aplinkosVersijos = ver;
for i = 1:numel(paketai)
    paketai{i}.schema = schema;
    paketai{i}.matlab_versija = version;
    paketai{i}.aplinkos_versijos = aplinkosVersijos;
    derinimoBalai{i} = prognozuotiBalus(paketai{i}, Xder);
    if i == 1
        paketai{i}.slenkstis = NaN;
        paketai{i}.sprendimoBud = "majority";
    else
        [paketai{i}.slenkstis, paketai{i}.sprendimoBud] = ...
            parinktiSlenksti(yder, derinimoBalai{i}, 0.01);
    end
    paketas = paketai{i};
    fprintf("Saugomas modelis %d/%d: %s\n", i, numel(paketai), modeliuPavadinimai(i));
    save(fullfile(modeliuAplankas, modeliuVersijos(i) + ".mat"), "paketas");
end

fprintf("Pasirinkti modeliai ismokyti, slenksciai parinkti tik derinimo imtyje.\n");

%% 6 etapas. Galutinis testas

Xtest = X(testoIndeksai, :);
ytest = y(testoIndeksai);
testoRowId = eilutesId(testoIndeksai);
testoGroupId = grupesId(testoIndeksai);

visosPrognozes = table;
visosMetrikos = table;
prKreives = cell(numel(paketai), 1);
galutinesKlases = cell(numel(paketai), 1);
galutiniaiBalai = cell(numel(paketai), 1);

for i = 1:numel(paketai)
    balai = prognozuotiBalus(paketai{i}, Xtest);
    if paketai{i}.sprendimoBud == "majority"
        klases = repmat(paketai{i}.dazniausiaKlase, size(ytest));
    elseif paketai{i}.sprendimoBud == "always_zero"
        klases = zeros(size(ytest));
    else
        klases = double(balai >= paketai{i}.slenkstis);
    end

    metrika = skaiciuotiMetrikas(ytest, klases, balai);
    metrika.modelis = modeliuPavadinimai(i);
    metrika.mokymo_laikas_s = mokymoLaikai(i);
    metrika.model_version = modeliuVersijos(i);
    metrika.threshold = paketai{i}.slenkstis;
    metrika.decision_mode = paketai{i}.sprendimoBud;
    visosMetrikos = [visosMetrikos; struct2table(metrika, ...
        'AsArray', true)]; %#ok<AGROW>

    prognozes = table(testoRowId, testoGroupId, repmat(modeliuPavadinimai(i), size(ytest)), ...
        ytest, klases, balai, repmat(paketai{i}.slenkstis, size(ytest)), ...
        repmat(modeliuVersijos(i), size(ytest)), ...
        'VariableNames', {'row_id', 'group_id', 'model', 'true_class', ...
        'class', 'score', 'threshold', 'model_version'});
    visosPrognozes = [visosPrognozes; prognozes]; %#ok<AGROW>
    prKreives{i} = sudarytiPrKreive(ytest, balai);
    galutinesKlases{i} = klases;
    galutiniaiBalai{i} = balai;
end

writetable(visosPrognozes, fullfile(rezultatuAplankas, "predictions.csv"));
writetable(visosMetrikos, fullfile(rezultatuAplankas, "metrics.csv"));

klaiduAnalize = sudarytiKlaiduAnalize(testoRowId, testoGroupId, ytest, ...
    modeliuPavadinimai, galutinesKlases, galutiniaiBalai, 5);
writetable(klaiduAnalize, fullfile(rezultatuAplankas, "klaidu_analize.csv"));

%% 6A etapas. Ablacijos galutinis vertinimas ir pakartojimai

XderBeDidziuju = Xder(:, 1:end-3);
XtestBeDidziuju = Xtest(:, 1:end-3);
schemaBeDidziuju = schema;
schemaBeDidziuju.pozymiai = schema.pozymiai(1:end-3);

abliacijosPavadinimai = ["RF be didziuju", "HCVR-RF be didziuju"];
abliacijosVersijos = ["rf_42_no_capitals", "hcvr_rf_42_no_capitals"];
abliacijosTipai = ["rf", "hcvr_rf"];
abliacijosParametrai = {
    struct("Medziai", geriausiasRfBeDidziuju.Medziai, ...
        "Lapas", geriausiasRfBeDidziuju.Lapas);
    struct("Medziai", geriausiasHcvrBeDidziuju.Medziai, ...
        "Lapas", geriausiasHcvrBeDidziuju.Lapas, ...
        "Theta", geriausiasHcvrBeDidziuju.Theta)};
abliacijosMetrikos = table;
abliacijosPrognozes = table;

for i = 1:2
    laikmatis = tic;
    paketas = mokytiModeli(XmokBeDidziuju, ymok, abliacijosTipai(i), ...
        abliacijosParametrai{i}, abliacijosVersijos(i), pradineReiksme);
    laikas = toc(laikmatis);
    paketas.schema = schemaBeDidziuju;
    paketas.matlab_versija = version;
    paketas.aplinkos_versijos = aplinkosVersijos;
    [paketas, metrika, klases, balai] = uzbaigtiPaketa(paketas, ...
        XderBeDidziuju, yder, XtestBeDidziuju, ytest, laikas, abliacijosPavadinimai(i));
    save(fullfile(modeliuAplankas, abliacijosVersijos(i) + ".mat"), "paketas");
    abliacijosMetrikos = [abliacijosMetrikos; metrika]; %#ok<AGROW>
    eilutes = table(testoRowId, testoGroupId, repmat(abliacijosPavadinimai(i), size(ytest)), ...
        ytest, klases, balai, repmat(paketas.slenkstis, size(ytest)), ...
        repmat(abliacijosVersijos(i), size(ytest)), ...
        'VariableNames', {'row_id', 'group_id', 'model', 'true_class', ...
        'class', 'score', 'threshold', 'model_version'});
    abliacijosPrognozes = [abliacijosPrognozes; eilutes]; %#ok<AGROW>
end
writetable(abliacijosMetrikos, fullfile(rezultatuAplankas, "ablation_metrics.csv"));
writetable(abliacijosPrognozes, fullfile(rezultatuAplankas, "ablation_predictions.csv"));

pakartojimuMetrikos = table;
pakartojimuPradines = [43, 44];
for seed = pakartojimuPradines
    for i = 1:2
        if i == 1
            tipas = "rf"; parametrai = rfParametrai; pavadinimas = "RF";
        else
            tipas = "hcvr_rf"; parametrai = hcvrParametrai; pavadinimas = "HCVR-RF";
        end
        versija = tipas + "_" + string(seed) + "_full";
        laikmatis = tic;
        paketas = mokytiModeli(Xmok, ymok, tipas, parametrai, versija, seed);
        laikas = toc(laikmatis);
        paketas.schema = schema;
        paketas.matlab_versija = version;
        paketas.aplinkos_versijos = aplinkosVersijos;
        [paketas, metrika] = uzbaigtiPaketa(paketas, Xder, yder, Xtest, ytest, ...
            laikas, pavadinimas + " seed " + string(seed));
        metrika.seed = seed;
        save(fullfile(modeliuAplankas, versija + ".mat"), "paketas");
        pakartojimuMetrikos = [pakartojimuMetrikos; metrika]; %#ok<AGROW>
    end
end
writetable(pakartojimuMetrikos, fullfile(rezultatuAplankas, "repeat_results.csv"));

%% 6B etapas. Grupine saviranka, intervalai ir hipotezes

[intervalai, hipotezes, praleistosImtys] = grupineSaviranka(ytest, testoGroupId, ...
    modeliuPavadinimai, galutinesKlases, galutiniaiBalai, 1000, pradineReiksme);
writetable(intervalai, fullfile(rezultatuAplankas, "intervals.csv"));
writetable(hipotezes, fullfile(rezultatuAplankas, "hypotheses.csv"));

%% 7 etapas. Kontrolines patikros ir auditas

testuotiMetrikas();
testuotiHcvrTaisykles();

didziausiasIkeltuBalasSkirtumas = 0;
visosIkeltosKlasesSutampa = true;
for i = 1:numel(paketai)
    ikeltas = load(fullfile(modeliuAplankas, modeliuVersijos(i) + ".mat"), "paketas");
    ikeltiBalai = prognozuotiBalus(ikeltas.paketas, Xtest);
    ikeltosKlases = klasifikuotiBalus(ikeltas.paketas, ikeltiBalai, ytest);
    didziausiasIkeltuBalasSkirtumas = max(didziausiasIkeltuBalasSkirtumas, ...
        max(abs(ikeltiBalai - galutiniaiBalai{i})));
    visosIkeltosKlasesSutampa = visosIkeltosKlasesSutampa && ...
        isequal(ikeltosKlases, galutinesKlases{i});
end
assert(visosIkeltosKlasesSutampa);
assert(didziausiasIkeltuBalasSkirtumas <= 1e-6);

perskaitytosPrognozes = readtable(fullfile(rezultatuAplankas, "predictions.csv"), ...
    "TextType", "string");
didziausiasMetrikuSkirtumas = 0;
for i = 1:numel(modeliuPavadinimai)
    pasirinkta = perskaitytosPrognozes.model == modeliuPavadinimai(i);
    perskaiciuota = skaiciuotiMetrikas(perskaitytosPrognozes.true_class(pasirinkta), ...
        perskaitytosPrognozes.class(pasirinkta), perskaitytosPrognozes.score(pasirinkta));
    laukai = ["precision", "recall", "fpr", "pr_auc", "average_precision", ...
        "cost_5", "cost_10", "cost_20"];
    for laukas = laukai
        pradine = visosMetrikos{i, laukas};
        nauja = perskaiciuota.(laukas);
        if ~(isnan(pradine) && isnan(nauja))
            didziausiasMetrikuSkirtumas = max(didziausiasMetrikuSkirtumas, abs(pradine - nauja));
        end
    end
end
assert(didziausiasMetrikuSkirtumas <= 1e-12);

configKontrolineSumaPoTesto = failoSha256(fullfile(rezultatuAplankas, "config.json"));
assert(strcmp(configKontrolineSumaPriesTesta, configKontrolineSumaPoTesto));

auditas = struct;
auditas.pradine_reiksme = pradineReiksme;
auditas.raw_sha256 = manifestas.raw_sha256;
auditas.mokymo_eiluciu = sum(mokymoIndeksai);
auditas.derinimo_eiluciu = sum(derinimoIndeksai);
auditas.testavimo_eiluciu = sum(testoIndeksai);
auditas.cv_deriniu = height(cvRezultatai);
auditas.abliacijos_cv_deriniu = height(abliacijosCv);
auditas.cv_daliu = vidiniuDaliuSkaicius;
auditas.mokymo_klase_0 = sum(ymok == 0);
auditas.mokymo_klase_1 = sum(ymok == 1);
auditas.derinimo_klase_0 = sum(yder == 0);
auditas.derinimo_klase_1 = sum(yder == 1);
auditas.testavimo_klase_0 = sum(ytest == 0);
auditas.testavimo_klase_1 = sum(ytest == 1);
auditas.mokymo_derinimo_row_sankirta = numel(intersect(eilutesId(mokymoIndeksai), eilutesId(derinimoIndeksai)));
auditas.mokymo_testo_row_sankirta = numel(intersect(eilutesId(mokymoIndeksai), eilutesId(testoIndeksai)));
auditas.derinimo_testo_row_sankirta = numel(intersect(eilutesId(derinimoIndeksai), eilutesId(testoIndeksai)));
auditas.mokymo_derinimo_group_sankirta = numel(intersect(grupesId(mokymoIndeksai), grupesId(derinimoIndeksai)));
auditas.mokymo_testo_group_sankirta = numel(intersect(grupesId(mokymoIndeksai), grupesId(testoIndeksai)));
auditas.derinimo_testo_group_sankirta = numel(intersect(grupesId(derinimoIndeksai), grupesId(testoIndeksai)));
auditas.metriku_kontrole = "TP=2, FP=1, FN=1, TN=6 patikrinta";
auditas.hcvr_kontrole = "Balsavimo sakos, lygybe, pastovus pozymis ir tuscia atranka patikrinti";
auditas.testo_naudojimas = "Testas atvertas tik po modeliu mokymo ir slenksciu parinkimo";
auditas.config_sha256_pries_testa = configKontrolineSumaPriesTesta;
auditas.config_sha256_po_testo = configKontrolineSumaPoTesto;
auditas.config_nepakito = strcmp(configKontrolineSumaPriesTesta, configKontrolineSumaPoTesto);
auditas.ikeltu_modeliu_klases_sutampa = visosIkeltosKlasesSutampa;
auditas.didziausias_ikeltu_score_skirtumas = didziausiasIkeltuBalasSkirtumas;
auditas.metrics_perskaiciavimo_didziausias_skirtumas = didziausiasMetrikuSkirtumas;
auditas.savirankos_bandymu = 1000;
auditas.savirankos_praleistu_imciu = praleistosImtys;
auditas.fit_indeksai = "fit_indeksai.csv";
auditas.vidiniu_daliu_indeksai = "duomenys/vidines_dalys.csv";
irasytiJson(fullfile(rezultatuAplankas, "audit.json"), auditas);

%% 8 etapas. Grafikai

kurtiGrafikus = strcmp(getenv("KOLIO_KURTI_GRAFIKUS"), "1");
if kurtiGrafikus
figura = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1000, 700]);
hold on;
spalvos = lines(numel(modeliuPavadinimai));
for i = 1:numel(prKreives)
    plot(prKreives{i}.jautrumas, prKreives{i}.preciziskumas, ...
        "LineWidth", 1.6, "Color", spalvos(i, :));
end
grid on;
xlabel("Jautrumas");
ylabel("Preciziškumas");
title("PR kreivės testavimo imtyje");
legend(modeliuPavadinimai, "Location", "southwest");
print(figura, fullfile(grafikuAplankas, "PR_kreives.png"), "-dpng", "-r300");
close(figura);

figura = figure("Visible", "off", "Color", "w", "Position", [100, 100, 1200, 650]);
tiledlayout(2, 3, "Padding", "compact", "TileSpacing", "compact");
for i = 1:numel(modeliuPavadinimai)
    nexttile;
    eilutes = visosPrognozes.model == modeliuPavadinimai(i);
    matrica = confusionmat(visosPrognozes.true_class(eilutes), visosPrognozes.class(eilutes), ...
        "Order", [0, 1]);
    imagesc(matrica);
    axis image;
    colormap(parula);
    colorbar;
    title(modeliuPavadinimai(i));
    xlabel("Prognozuota klasė");
    ylabel("Tikroji klasė");
    xticks([1, 2]); yticks([1, 2]);
    xticklabels({"0", "1"}); yticklabels({"0", "1"});
    for r = 1:2
        for c = 1:2
            text(c, r, string(matrica(r, c)), "HorizontalAlignment", "center", ...
                "FontWeight", "bold", "Color", "w");
        end
    end
end
print(figura, fullfile(grafikuAplankas, "klaidu_matricos.png"), "-dpng", "-r300");
close(figura);
else
    fprintf("Grafikai praleisti. MATLAB Online eksportas gali uzstrigti; ijungti: setenv('KOLIO_KURTI_GRAFIKUS','1').\n");
end

%% 9 etapas. Rezultatu suvestine

disp(visosMetrikos(:, {'modelis', 'precision', 'recall', 'fpr', 'pr_auc', ...
    'average_precision', 'cost_5', 'cost_10', 'cost_20', ...
    'FP', 'FN', 'mokymo_laikas_s'}));
fprintf("\nHipoteziu vertinimas pagal 1000 grupines savirankos bandymu:\n");
disp(hipotezes);
fprintf("\nHiperparametru paieska ir galutinis vertinimas baigti.\n");
fprintf("Rezultatu aplankas: %s\n", rezultatuAplankas);

%% Vietines funkcijos

function pavadinimai = nuskaitytiPozymiuPavadinimus(failas)
    tekstas = splitlines(string(fileread(failas)));
    pavadinimai = strings(0, 1);
    for i = 1:numel(tekstas)
        atitikmuo = regexp(tekstas(i), '^\s*([^|][^:]+):\s*continuous\.', 'tokens', 'once');
        if ~isempty(atitikmuo)
            pavadinimai(end + 1, 1) = strtrim(string(atitikmuo{1})); %#ok<AGROW>
        end
    end
end

function irasytRawCsv(failas, rowId, X, y, pavadinimai)
    antraste = [{"row_id"}, cellstr(pavadinimai(:))', {"target"}];
    writecell(antraste, failas, "Delimiter", ",", "Encoding", "UTF-8");
    writematrix([rowId, X, y], failas, "WriteMode", "append", "Delimiter", ",");
end

function irasytiJson(failas, duomenys)
    tekstas = jsonencode(duomenys, "PrettyPrint", true);
    failoId = fopen(failas, "w", "n", "UTF-8");
    if failoId < 0
        error("Nepavyko sukurti failo: %s", failas);
    end
    valymas = onCleanup(@() fclose(failoId));
    fprintf(failoId, "%s", tekstas);
end

function suma = failoSha256(failas)
    failoId = fopen(failas, "r");
    if failoId < 0
        error("Nepavyko atverti failo kontrolinei sumai: %s", failas);
    end
    valymas = onCleanup(@() fclose(failoId));
    baitai = fread(failoId, Inf, "*uint8");
    objektas = java.security.MessageDigest.getInstance("SHA-256");
    objektas.update(typecast(baitai, "int8"));
    suma = lower(reshape(dec2hex(typecast(objektas.digest(), "uint8"), 2)', 1, []));
end

function patikrintiSkaidyma(y, grupesId, mokymas, derinimas, testas)
    if any(mokymas & derinimas) || any(mokymas & testas) || any(derinimas & testas)
        error("Eiluciu skaidymai persidengia.");
    end
    if ~all(mokymas | derinimas | testas)
        error("Ne visos eilutes priskirtos skaidymui.");
    end
    poros = {mokymas, derinimas; mokymas, testas; derinimas, testas};
    for i = 1:size(poros, 1)
        if ~isempty(intersect(grupesId(poros{i, 1}), grupesId(poros{i, 2})))
            error("Vienoda pozymiu grupe pateko i kelias imtis.");
        end
    end
    dalys = {mokymas, derinimas, testas};
    for i = 1:numel(dalys)
        if numel(unique(y(dalys{i}))) ~= 2
            error("Skaidymo dalyje %d nera abieju klasiu.", i);
        end
    end
end

function daliesNumeris = sudarytiVidinesDalis(y, grupesId, daliuSkaicius, seed)
    unikaliosGrupes = unique(grupesId, "stable");
    grupiuKlases = zeros(numel(unikaliosGrupes), 1);
    for i = 1:numel(unikaliosGrupes)
        grupiuKlases(i) = mode(y(grupesId == unikaliosGrupes(i)));
    end

    rng(seed, "twister");
    skaidymas = cvpartition(grupiuKlases, "KFold", daliuSkaicius);
    dalisGrupei = zeros(numel(unikaliosGrupes), 1);
    for dalis = 1:daliuSkaicius
        dalisGrupei(test(skaidymas, dalis)) = dalis;
    end

    [~, grupesVieta] = ismember(grupesId, unikaliosGrupes);
    daliesNumeris = dalisGrupei(grupesVieta);

    for dalis = 1:daliuSkaicius
        mokymas = daliesNumeris ~= dalis;
        patikra = daliesNumeris == dalis;
        if ~isempty(intersect(grupesId(mokymas), grupesId(patikra)))
            error("Vidines patikros grupes persidengia %d dalyje.", dalis);
        end
        if numel(unique(y(mokymas))) ~= 2 || numel(unique(y(patikra))) ~= 2
            error("Vidines patikros %d dalyje nera abieju klasiu.", dalis);
        end
    end
end

function eilute = tusciaCvEilute()
    eilute = struct("bandymo_id", NaN, "modelis", "", ...
        "Lambda", NaN, "C", NaN, "Gamma", NaN, "Medziai", NaN, ...
        "Lapas", NaN, "Theta", NaN, "fold1_pr_auc", NaN, ...
        "fold2_pr_auc", NaN, "fold3_pr_auc", NaN, ...
        "vidutinis_pr_auc", NaN, "pozymiu_skaicius", NaN, ...
        "mokymo_laikas_s", NaN, "fold1_kauke", "", ...
        "fold2_kauke", "", "fold3_kauke", "");
end

function eilute = vertintiDerini(X, y, daliesNumeris, modelioPavadinimas, ...
        tipas, parametrai, bandymoId, seed, etapas, visoDeriniu)
    if nargin < 9
        etapas = "CV";
        visoDeriniu = 35;
    end
    daliuSkaicius = max(daliesNumeris);
    prAuc = nan(1, daliuSkaicius);
    pozymiuKiekiai = nan(1, daliuSkaicius);
    laikai = nan(1, daliuSkaicius);
    kaukes = strings(1, daliuSkaicius);

    for dalis = 1:daliuSkaicius
        mokymas = daliesNumeris ~= dalis;
        patikra = daliesNumeris == dalis;
        laikmatis = tic;
        paketas = mokytiModeli(X(mokymas, :), y(mokymas), tipas, ...
            parametrai, "cv", seed + dalis);
        laikai(dalis) = toc(laikmatis);
        balai = prognozuotiBalus(paketas, X(patikra, :));
        kreive = sudarytiPrKreive(y(patikra), balai);
        prAuc(dalis) = kreive.plotas;
        pozymiuKiekiai(dalis) = sum(paketas.pozymiuKauke);
        kaukes(dalis) = join(string(double(paketas.pozymiuKauke)), "");
    end

    eilute = tusciaCvEilute();
    eilute.bandymo_id = bandymoId;
    eilute.modelis = modelioPavadinimas;
    eilute.Lambda = parametroReiksme(parametrai, "Lambda");
    eilute.C = parametroReiksme(parametrai, "C");
    eilute.Gamma = parametroReiksme(parametrai, "Gamma");
    eilute.Medziai = parametroReiksme(parametrai, "Medziai");
    eilute.Lapas = parametroReiksme(parametrai, "Lapas");
    eilute.Theta = parametroReiksme(parametrai, "Theta");
    eilute.fold1_pr_auc = prAuc(1);
    eilute.fold2_pr_auc = prAuc(2);
    eilute.fold3_pr_auc = prAuc(3);
    eilute.vidutinis_pr_auc = mean(prAuc);
    eilute.pozymiu_skaicius = mean(pozymiuKiekiai);
    eilute.mokymo_laikas_s = sum(laikai);
    eilute.fold1_kauke = kaukes(1);
    eilute.fold2_kauke = kaukes(2);
    eilute.fold3_kauke = kaukes(3);

    fprintf("%s %2d/%d: %-22s PR-AUC %.5f, pozymiai %.1f, laikas %.2f s\n", ...
        etapas, bandymoId, visoDeriniu, modelioPavadinimas, eilute.vidutinis_pr_auc, ...
        eilute.pozymiu_skaicius, eilute.mokymo_laikas_s);
end

function reiksme = parametroReiksme(parametrai, laukas)
    if isfield(parametrai, laukas)
        reiksme = parametrai.(laukas);
    else
        reiksme = NaN;
    end
end

function geriausia = parinktiGeriausiaDerini(rezultatai, modelis)
    kandidatai = rezultatai(rezultatai.modelis == modelis & ...
        isfinite(rezultatai.vidutinis_pr_auc), :);
    if isempty(kandidatai)
        error("Modeliui %s nera tinkamu CV rezultatu.", modelis);
    end

    geriausiasPrAuc = max(kandidatai.vidutinis_pr_auc);
    kandidatai = kandidatai(geriausiasPrAuc - kandidatai.vidutinis_pr_auc < 0.001, :);
    maziausiaiPozymiu = min(kandidatai.pozymiu_skaicius);
    kandidatai = kandidatai(kandidatai.pozymiu_skaicius == maziausiaiPozymiu, :);
    trumpiausiasLaikas = min(kandidatai.mokymo_laikas_s);
    kandidatai = kandidatai(kandidatai.mokymo_laikas_s == trumpiausiasLaikas, :);
    geriausia = kandidatai(1, :);
end

function aprasas = pasirinkimoAprasas(eilute, parametrai)
    aprasas = struct;
    aprasas.bandymo_id = eilute.bandymo_id;
    aprasas.parametrai = parametrai;
    aprasas.vidutinis_pr_auc = eilute.vidutinis_pr_auc;
    aprasas.pozymiu_skaicius = eilute.pozymiu_skaicius;
    aprasas.cv_mokymo_laikas_s = eilute.mokymo_laikas_s;
end

function paketas = mokytiDaugumosModeli(y, versija)
    kiekiai = [sum(y == 0), sum(y == 1)];
    if kiekiai(2) > kiekiai(1)
        dazniausia = 1;
    else
        dazniausia = 0;
    end
    paketas = struct("tipas", "majority", "versija", versija, ...
        "dazniausiaKlase", dazniausia, "brukaloDalis", mean(y), ...
        "slenkstis", NaN, "sprendimoBud", "majority");
end

function paketas = mokytiModeli(X, y, tipas, parametrai, versija, seed)
    rng(seed, "twister");
    [Xparuostas, paruosimas] = parengtiMokymui(X);
    kauke = true(1, size(X, 2));

    if tipas == "hcvr_rf"
        kauke = hcvrAtranka(Xparuostas, y, parametrai.Theta);
        if ~any(kauke)
            error("HCVR nepaliko ne vieno pozymio. Sis derinys turi buti atmestas.");
        end
        Xparuostas = Xparuostas(:, kauke);
    end

    switch tipas
        case "lr"
            [Xparuostas, paruosimas] = standartizuotiMokymui(Xparuostas, paruosimas, kauke);
            modelis = fitclinear(Xparuostas, y, "Learner", "logistic", ...
                "Regularization", "ridge", "Lambda", parametrai.Lambda, ...
                "Solver", "lbfgs", "ClassNames", [0; 1]);
        case "svm"
            [Xparuostas, paruosimas] = standartizuotiMokymui(Xparuostas, paruosimas, kauke);
            modelis = fitcsvm(Xparuostas, y, "KernelFunction", "gaussian", ...
                "BoxConstraint", parametrai.C, "KernelScale", 1 / sqrt(parametrai.Gamma), ...
                "Standardize", false, "ClassNames", [0; 1]);
        case {"rf", "hcvr_rf"}
            p = size(Xparuostas, 2);
            modelis = TreeBagger(parametrai.Medziai, Xparuostas, y, ...
                "Method", "classification", "MinLeafSize", parametrai.Lapas, ...
                "NumPredictorsToSample", max(1, floor(sqrt(p))), ...
                "SampleWithReplacement", "on", "OOBPrediction", "off");
        otherwise
            error("Nezinomas modelio tipas: %s", tipas);
    end

    paketas = struct("tipas", tipas, "versija", versija, "parametrai", parametrai, ...
        "paruosimas", paruosimas, "pozymiuKauke", kauke, "modelis", modelis, ...
        "slenkstis", NaN, "sprendimoBud", "threshold");
end

function [Xparuostas, paruosimas] = parengtiMokymui(X)
    medianos = median(X, 1, "omitnan");
    if any(isnan(medianos))
        error("Bent vienas mokymo pozymis yra visiskai tuscias.");
    end
    Xparuostas = X;
    for j = 1:size(X, 2)
        truksta = isnan(Xparuostas(:, j));
        Xparuostas(truksta, j) = medianos(j);
    end
    paruosimas = struct("medianos", medianos, "vidurkiai", [], "nuokrypiai", [], ...
        "standartizuoti", false);
end

function [X, paruosimas] = standartizuotiMokymui(X, paruosimas, kauke)
    vidurkiai = mean(X, 1);
    nuokrypiai = std(X, 0, 1);
    nuokrypiai(nuokrypiai == 0) = 1;
    X = (X - vidurkiai) ./ nuokrypiai;
    paruosimas.vidurkiai = vidurkiai;
    paruosimas.nuokrypiai = nuokrypiai;
    paruosimas.standartizuoti = true;
    paruosimas.standartizuotaKauke = kauke;
end

function X = pritaikytiParuosima(paruosimas, kauke, X)
    for j = 1:size(X, 2)
        truksta = isnan(X(:, j));
        X(truksta, j) = paruosimas.medianos(j);
    end
    X = X(:, kauke);
    if paruosimas.standartizuoti
        X = (X - paruosimas.vidurkiai) ./ paruosimas.nuokrypiai;
    end
end

function balai = prognozuotiBalus(paketas, X)
    if paketas.tipas == "majority"
        balai = repmat(paketas.brukaloDalis, size(X, 1), 1);
        return;
    end

    X = pritaikytiParuosima(paketas.paruosimas, paketas.pozymiuKauke, X);
    if paketas.tipas == "rf" || paketas.tipas == "hcvr_rf"
        [~, visiBalai] = predict(paketas.modelis, X);
        klases = string(paketas.modelis.ClassNames);
        stulpelis = find(str2double(klases) == 1, 1);
    else
        [~, visiBalai] = predict(paketas.modelis, X);
        stulpelis = find(paketas.modelis.ClassNames == 1, 1);
    end
    if isempty(stulpelis)
        error("Modelio isvestyje nerasta klases 1 balo.");
    end
    balai = visiBalai(:, stulpelis);
end

function kauke = hcvrAtranka(X, y, theta)
    nepastovus = std(X, 0, 1) > 0;
    aktyvus = find(nepastovus);
    if isempty(aktyvus)
        kauke = false(1, size(X, 2));
        return;
    end

    while numel(aktyvus) > 1
        balsai = zeros(1, numel(aktyvus));
        for a = 1:numel(aktyvus)-1
            for b = a+1:numel(aktyvus)
                i = aktyvus(a);
                j = aktyvus(b);
                rij = abs(corr(X(:, i), X(:, j), "Rows", "complete"));
                riy = abs(corr(X(:, i), y, "Rows", "complete"));
                rjy = abs(corr(X(:, j), y, "Rows", "complete"));
                [balsasI, balsasJ] = hcvrPorosBalsas(rij, riy, rjy, theta, i, j);
                balsai(a) = balsai(a) + balsasI;
                balsai(b) = balsai(b) + balsasJ;
            end
        end
        nauji = aktyvus(balsai > (numel(aktyvus) - 1) / 2);
        if isempty(nauji)
            aktyvus = [];
            break;
        end
        if isequal(nauji, aktyvus)
            break;
        end
        aktyvus = nauji;
    end

    kauke = false(1, size(X, 2));
    kauke(aktyvus) = true;
end

function [balsasI, balsasJ] = hcvrPorosBalsas(rij, riy, rjy, theta, i, j)
    if isnan(rij), rij = 0; end
    if isnan(riy), riy = 0; end
    if isnan(rjy), rjy = 0; end
    highI = riy >= theta;
    highJ = rjy >= theta;
    highPora = rij >= theta;
    balsasI = 0;
    balsasJ = 0;

    if ~highI && ~highJ
        return;
    elseif highI && ~highJ
        balsasI = 1;
    elseif ~highI && highJ
        balsasJ = 1;
    elseif ~highPora
        balsasI = 1;
        balsasJ = 1;
    elseif riy > rjy || (riy == rjy && i < j)
        balsasI = 1;
    else
        balsasJ = 1;
    end
end

function [slenkstis, budas] = parinktiSlenksti(y, balai, didziausiasFpr)
    kandidatai = [Inf; sort(unique(balai), "descend")];
    geriausiasJautrumas = -Inf;
    geriausiasFpr = Inf;
    slenkstis = Inf;

    for i = 1:numel(kandidatai)
        klases = double(balai >= kandidatai(i));
        m = skaiciuotiMetrikas(y, klases, balai);
        if m.fpr <= didziausiasFpr
            geresnis = m.recall > geriausiasJautrumas || ...
                (m.recall == geriausiasJautrumas && m.fpr < geriausiasFpr) || ...
                (m.recall == geriausiasJautrumas && m.fpr == geriausiasFpr && kandidatai(i) > slenkstis);
            if geresnis
                geriausiasJautrumas = m.recall;
                geriausiasFpr = m.fpr;
                slenkstis = kandidatai(i);
            end
        end
    end

    if isinf(slenkstis)
        slenkstis = NaN;
        budas = "always_zero";
    else
        budas = "threshold";
    end
end

function m = skaiciuotiMetrikas(y, klases, balai)
    TP = sum(y == 1 & klases == 1);
    FP = sum(y == 0 & klases == 1);
    FN = sum(y == 1 & klases == 0);
    TN = sum(y == 0 & klases == 0);
    N = numel(y);

    m = struct;
    m.TP = TP; m.FP = FP; m.FN = FN; m.TN = TN;
    m.precision = saugiDalyba(TP, TP + FP);
    m.recall = saugiDalyba(TP, TP + FN);
    m.fpr = saugiDalyba(FP, FP + TN);
    kreive = sudarytiPrKreive(y, balai);
    m.pr_auc = kreive.plotas;
    m.average_precision = vidutinisPreciziskumas(y, balai);
    m.cost_5 = (5 * FP + FN) / N;
    m.cost_10 = (10 * FP + FN) / N;
    m.cost_20 = (20 * FP + FN) / N;
end

function rezultatas = saugiDalyba(skaitiklis, vardiklis)
    if vardiklis == 0
        rezultatas = NaN;
    else
        rezultatas = skaitiklis / vardiklis;
    end
end

function kreive = sudarytiPrKreive(y, balai)
    [jautrumas, preciziskumas, ~, plotas] = perfcurve(y, balai, 1, ...
        "XCrit", "reca", "YCrit", "prec");
    galioja = isfinite(jautrumas) & isfinite(preciziskumas);
    kreive = struct("jautrumas", jautrumas(galioja), ...
        "preciziskumas", preciziskumas(galioja), "plotas", plotas);
end

function ap = vidutinisPreciziskumas(y, balai)
    [surikiuotiBalai, tvarka] = sort(balai, "descend");
    surikiuotaY = y(tvarka);
    teigiamuSkaicius = sum(y == 1);
    if teigiamuSkaicius == 0
        ap = NaN;
        return;
    end

    % Vienodus balus vertiname kaip viena slenkscio grupe, kad rezultatas
    % nepriklausytu nuo pradines vienodus balus turinciu eiluciu tvarkos.
    grupesPabaiga = [find(diff(surikiuotiBalai) ~= 0); numel(y)];
    sukauptiTeigiami = cumsum(surikiuotaY == 1);
    teigiamiGrupese = diff([0; sukauptiTeigiami(grupesPabaiga)]);
    preciziskumasGrupese = sukauptiTeigiami(grupesPabaiga) ./ grupesPabaiga;
    ap = sum((teigiamiGrupese / teigiamuSkaicius) .* preciziskumasGrupese);
end

function testuotiMetrikas()
    y = [1; 1; 1; 0; 0; 0; 0; 0; 0; 0];
    klases = [1; 1; 0; 1; 0; 0; 0; 0; 0; 0];
    balai = double(klases);
    m = skaiciuotiMetrikas(y, klases, balai);
    assert(abs(m.precision - 2/3) < 1e-12);
    assert(abs(m.recall - 2/3) < 1e-12);
    assert(abs(m.fpr - 1/7) < 1e-12);
    assert(abs(m.cost_10 - 1.1) < 1e-12);
    pastovusAp = vidutinisPreciziskumas(y, zeros(size(y)));
    assert(abs(pastovusAp - mean(y)) < 1e-12);
end

function testuotiHcvrTaisykles()
    [a, b] = hcvrPorosBalsas(0.9, 0.01, 0.01, 0.04, 1, 2);
    assert(a == 0 && b == 0);
    [a, b] = hcvrPorosBalsas(0.9, 0.2, 0.01, 0.04, 1, 2);
    assert(a == 1 && b == 0);
    [a, b] = hcvrPorosBalsas(0.9, 0.01, 0.2, 0.04, 1, 2);
    assert(a == 0 && b == 1);
    [a, b] = hcvrPorosBalsas(0.01, 0.2, 0.2, 0.04, 1, 2);
    assert(a == 1 && b == 1);
    [a, b] = hcvrPorosBalsas(0.9, 0.3, 0.2, 0.04, 1, 2);
    assert(a == 1 && b == 0);
    [a, b] = hcvrPorosBalsas(0.9, 0.2, 0.2, 0.04, 1, 2);
    assert(a == 1 && b == 0);
    y = [0; 0; 1; 1];
    assert(~any(hcvrAtranka(ones(4, 2), y, 0.04)));
    assert(isequal(hcvrAtranka([0; 1; 2; 3], y, 0.04), true(1, 1)));
end

function [paketas, metrika, klases, balai] = uzbaigtiPaketa(paketas, ...
        Xder, yder, Xtest, ytest, mokymoLaikas, pavadinimas)
    derinimoBalai = prognozuotiBalus(paketas, Xder);
    [paketas.slenkstis, paketas.sprendimoBud] = ...
        parinktiSlenksti(yder, derinimoBalai, 0.01);
    balai = prognozuotiBalus(paketas, Xtest);
    klases = klasifikuotiBalus(paketas, balai, ytest);
    m = skaiciuotiMetrikas(ytest, klases, balai);
    m.modelis = string(pavadinimas);
    m.mokymo_laikas_s = mokymoLaikas;
    m.model_version = string(paketas.versija);
    m.threshold = paketas.slenkstis;
    m.decision_mode = paketas.sprendimoBud;
    metrika = struct2table(m, 'AsArray', true);
end

function klases = klasifikuotiBalus(paketas, balai, yDydis)
    if paketas.sprendimoBud == "majority"
        klases = repmat(paketas.dazniausiaKlase, size(yDydis));
    elseif paketas.sprendimoBud == "always_zero"
        klases = zeros(size(yDydis));
    else
        klases = double(balai >= paketas.slenkstis);
    end
end

function lentele = sudarytiKlaiduAnalize(rowId, groupId, y, ...
        modeliai, klases, balai, kiekis)
    lentele = table;
    for i = 1:numel(modeliai)
        fp = find(y == 0 & klases{i} == 1);
        fn = find(y == 1 & klases{i} == 0);
        [~, tvarkaFp] = sort(balai{i}(fp), "descend");
        [~, tvarkaFn] = sort(balai{i}(fn), "ascend");
        fp = fp(tvarkaFp(1:min(kiekis, numel(fp))));
        fn = fn(tvarkaFn(1:min(kiekis, numel(fn))));
        indeksai = [fp; fn];
        tipai = [repmat("FP", numel(fp), 1); repmat("FN", numel(fn), 1)];
        if isempty(indeksai)
            continue;
        end
        dalis = table(rowId(indeksai), groupId(indeksai), ...
            repmat(modeliai(i), numel(indeksai), 1), tipai, y(indeksai), ...
            klases{i}(indeksai), balai{i}(indeksai), ...
            'VariableNames', {'row_id', 'group_id', 'modelis', 'klaidos_tipas', ...
            'tikroji_klase', 'prognozuota_klase', 'score'});
        lentele = [lentele; dalis]; %#ok<AGROW>
    end
end

function [intervalai, hipotezes, praleista] = grupineSaviranka(y, grupes, ...
        modeliai, klases, balai, bandymuSkaicius, seed)
    rng(seed, "twister");
    unikaliosGrupes = unique(grupes, "stable");
    grupiuEilutes = cell(numel(unikaliosGrupes), 1);
    for i = 1:numel(unikaliosGrupes)
        grupiuEilutes{i} = find(grupes == unikaliosGrupes(i));
    end

    metrikos = ["precision", "recall", "fpr", "pr_auc", ...
        "average_precision", "cost_5", "cost_10", "cost_20"];
    reiksmes = nan(bandymuSkaicius, numel(modeliai), numel(metrikos));
    praleista = 0;
    for bandymas = 1:bandymuSkaicius
        pasirinktos = randi(numel(unikaliosGrupes), numel(unikaliosGrupes), 1);
        indeksai = vertcat(grupiuEilutes{pasirinktos});
        if numel(unique(y(indeksai))) < 2
            praleista = praleista + 1;
            continue;
        end
        for m = 1:numel(modeliai)
            s = skaiciuotiMetrikas(y(indeksai), klases{m}(indeksai), balai{m}(indeksai));
            for j = 1:numel(metrikos)
                reiksmes(bandymas, m, j) = s.(metrikos(j));
            end
        end
    end

    eilutes = repmat(struct("modelis", "", "metrika", "", "ivertis", NaN, ...
        "apatine_95", NaN, "virsutine_95", NaN, "galiojancios_imtys", 0), ...
        numel(modeliai) * numel(metrikos), 1);
    e = 0;
    pilnosMetrikos = cell(numel(modeliai), 1);
    for m = 1:numel(modeliai)
        pilnosMetrikos{m} = skaiciuotiMetrikas(y, klases{m}, balai{m});
        for j = 1:numel(metrikos)
            e = e + 1;
            v = reiksmes(:, m, j);
            v = v(isfinite(v));
            ribos = prctile(v, [2.5, 97.5]);
            eilutes(e).modelis = modeliai(m);
            eilutes(e).metrika = metrikos(j);
            eilutes(e).ivertis = pilnosMetrikos{m}.(metrikos(j));
            eilutes(e).apatine_95 = ribos(1);
            eilutes(e).virsutine_95 = ribos(2);
            eilutes(e).galiojancios_imtys = numel(v);
        end
    end
    intervalai = struct2table(eilutes);

    lr = find(modeliai == "Logistine regresija", 1);
    rf = find(modeliai == "Atsitiktinis miskas", 1);
    hcvr = find(modeliai == "HCVR-RF", 1);
    prVieta = find(metrikos == "pr_auc", 1);
    skirtumai = [reiksmes(:, hcvr, prVieta) - reiksmes(:, lr, prVieta), ...
        reiksmes(:, hcvr, prVieta) - reiksmes(:, rf, prVieta)];
    taskiniai = [pilnosMetrikos{hcvr}.pr_auc - pilnosMetrikos{lr}.pr_auc; ...
        pilnosMetrikos{hcvr}.pr_auc - pilnosMetrikos{rf}.pr_auc];
    ribos = nan(2, 2);
    for i = 1:2
        v = skirtumai(:, i);
        v = v(isfinite(v));
        ribos(i, :) = prctile(v, [2.5, 97.5]);
    end
    skaitinisSiekinys = taskiniai >= 0.01;
    teigiamaApatineRiba = ribos(:, 1) > 0;
    patvirtinta = skaitinisSiekinys & teigiamaApatineRiba;
    isvada = repmat("nepatvirtinta", 2, 1);
    isvada(patvirtinta) = "patvirtinta";
    hipotezes = table(["H1"; "H2"], ["HCVR-RF - LR"; "HCVR-RF - RF"], ...
        taskiniai, ribos(:, 1), ribos(:, 2), repmat(0.01, 2, 1), ...
        skaitinisSiekinys, teigiamaApatineRiba, isvada, ...
        'VariableNames', {'hipoteze', 'palyginimas', 'pr_auc_skirtumas', ...
        'apatine_95', 'virsutine_95', 'siekinys', 'siekinys_pasiektas', ...
        'apatine_riba_teigiama', 'isvada'});
end

function pakeitimai = sukurtiPakeitimuLentele(cv, lr, svm, rf, hcvr, rfBe, hcvrBe)
    pradiniai = [
        cv(cv.modelis == "Logistine regresija" & cv.Lambda == 0.001, :);
        cv(cv.modelis == "SVM" & cv.C == 1 & cv.Gamma == 0.01, :);
        cv(cv.modelis == "Atsitiktinis miskas" & cv.Medziai == 100 & cv.Lapas == 1, :);
        cv(cv.modelis == "HCVR-RF" & cv.Medziai == 100 & cv.Lapas == 1 & cv.Theta == 0.04, :)];
    parinkti = [lr; svm; rf; hcvr];
    modeliai = ["Logistine regresija"; "SVM"; "Atsitiktinis miskas"; "HCVR-RF"];
    pakeitimai = table;
    for i = 1:4
        dalis = table("pagrindine paieska", modeliai(i), pradiniai.bandymo_id(i), ...
            parinkti.bandymo_id(i), pradiniai.vidutinis_pr_auc(i), ...
            parinkti.vidutinis_pr_auc(i), ...
            parinkti.vidutinis_pr_auc(i) - pradiniai.vidutinis_pr_auc(i), ...
            "parinktas pagal vidutini PR-AUC ir lygiuju taisykle", ...
            'VariableNames', {'etapas', 'modelis', 'pradinis_bandymo_id', ...
            'parinktas_bandymo_id', 'pradinis_pr_auc', 'parinktas_pr_auc', ...
            'pokytis', 'sprendimas'});
        pakeitimai = [pakeitimai; dalis]; %#ok<AGROW>
    end
    abliacijosParinkti = [rfBe; hcvrBe];
    pilni = [rf; hcvr];
    pavadinimai = ["RF be didziuju"; "HCVR-RF be didziuju"];
    for i = 1:2
        dalis = table("abliacija", pavadinimai(i), pilni.bandymo_id(i), ...
            abliacijosParinkti.bandymo_id(i), pilni.vidutinis_pr_auc(i), ...
            abliacijosParinkti.vidutinis_pr_auc(i), ...
            abliacijosParinkti.vidutinis_pr_auc(i) - pilni.vidutinis_pr_auc(i), ...
            "ivertintas 3 didziuju raidziu pozymiu pasalinimo poveikis", ...
            'VariableNames', pakeitimai.Properties.VariableNames);
        pakeitimai = [pakeitimai; dalis]; %#ok<AGROW>
    end
end

function irasytiFitIndeksus(failas, rowId, dalys, pagrindiniu, abliacijos)
    bandymuSkaiciai = [pagrindiniu, abliacijos];
    bendras = sum(bandymuSkaiciai) * 2 * numel(rowId);
    paieska = zeros(bendras, 1);
    bandymoId = zeros(bendras, 1);
    cvFold = zeros(bendras, 1);
    mokymoRowId = zeros(bendras, 1);
    vieta = 0;
    for p = 1:2
        for b = 1:bandymuSkaiciai(p)
            for dalis = 1:max(dalys)
                indeksai = find(dalys ~= dalis);
                n = numel(indeksai);
                vietos = vieta + (1:n);
                paieska(vietos) = p;
                bandymoId(vietos) = b;
                cvFold(vietos) = dalis;
                mokymoRowId(vietos) = rowId(indeksai);
                vieta = vieta + n;
            end
        end
    end
    fitLentele = table(paieska(1:vieta), bandymoId(1:vieta), ...
        cvFold(1:vieta), mokymoRowId(1:vieta), ...
        'VariableNames', {'paieska', 'bandymo_id', 'cv_fold', 'mokymo_row_id'});
    writetable(fitLentele, failas);
end
