%% ISORINIS MODELIU TESTAS SU SPAMASSASSIN PUBLIC CORPUS
% Mantas Matusevicius, DISfm-26
%
% Jau ismokyti modeliai nekeiciami ir nemokomi is naujo. Programa atsisiuncia
% nepriklausoma laisku rinkini, apskaiciuoja tuos pacius 57 Spambase pozymius
% ir ivertina issaugotus modelius su naujais duomenimis.

clear;
clc;
rng(20260929, "twister");

%% 1 etapas. Aplanku ir saltiniu paruosimas

programosFailas = mfilename("fullpath");
if strlength(programosFailas) == 0
    darboAplankas = pwd;
else
    darboAplankas = fileparts(programosFailas);
end

modeliuAplankas = fullfile(darboAplankas, ...
    "Koliokviumo_rezultatai", "modeliai");
duomenuAplankas = fullfile(darboAplankas, ...
    "duomenys", "spamassassin_public_corpus");
rezultatuAplankas = fullfile(darboAplankas, ...
    "Koliokviumo_rezultatai", "isorinis_testas_spamassassin");

if ~isfolder(duomenuAplankas), mkdir(duomenuAplankas); end
if ~isfolder(rezultatuAplankas), mkdir(rezultatuAplankas); end
if ~isfolder(modeliuAplankas)
    error("Modeliu aplankas nerastas: %s", modeliuAplankas);
end

bazineNuoroda = "https://spamassassin.apache.org/old/publiccorpus/";
archyvai = [
    "20030228_easy_ham.tar.bz2"
    "20030228_easy_ham_2.tar.bz2"
    "20030228_hard_ham.tar.bz2"
    "20030228_spam.tar.bz2"
    "20050311_spam_2.tar.bz2"];
grupes = ["easy_ham"; "easy_ham_2"; "hard_ham"; "spam"; "spam_2"];
klasesPagalGrupe = [0; 0; 0; 1; 1];
laukiamiKiekiai = [2500; 1400; 250; 500; 1396];

fprintf("Isorinis SpamAssassin Public Corpus testas\n");
fprintf("Modeliai nebus permokomi ir ju slenksciai nebus keiciami.\n\n");

%% 2 etapas. Oficialiu duomenu atsisiuntimas ir patikra

for i = 1:numel(archyvai)
    archyvoFailas = fullfile(duomenuAplankas, archyvai(i));
    grupesAplankas = fullfile(duomenuAplankas, grupes(i));
    if ~isfile(archyvoFailas)
        fprintf("Atsisiunciamas %s...\n", archyvai(i));
        websave(archyvoFailas, bazineNuoroda + archyvai(i));
    end
    if ~isfolder(grupesAplankas)
        fprintf("Ispakuojamas %s...\n", archyvai(i));
        komanda = sprintf('python3 -m tarfile -e "%s" "%s"', ...
            archyvoFailas, duomenuAplankas);
        [busena, pranesimas] = system(komanda);
        if busena ~= 0
            error("Nepavyko ispakuoti %s: %s", archyvai(i), pranesimas);
        end
    end
end

visiFailai = strings(0, 1);
visosGrupes = strings(0, 1);
y = zeros(0, 1);

for i = 1:numel(grupes)
    grupesAplankas = fullfile(duomenuAplankas, grupes(i));
    sarasas = dir(fullfile(grupesAplankas, "*"));
    sarasas = sarasas(~[sarasas.isdir]);
    sarasas = sarasas(~strcmpi({sarasas.name}, "cmds"));
    if numel(sarasas) ~= laukiamiKiekiai(i)
        error("Grupeje %s tiketasi %d laisku, gauta %d.", ...
            grupes(i), laukiamiKiekiai(i), numel(sarasas));
    end
    keliai = string(fullfile({sarasas.folder}, {sarasas.name}))';
    visiFailai = [visiFailai; keliai]; %#ok<AGROW>
    visosGrupes = [visosGrupes; repmat(grupes(i), numel(sarasas), 1)]; %#ok<AGROW>
    y = [y; repmat(klasesPagalGrupe(i), numel(sarasas), 1)]; %#ok<AGROW>
end

if numel(visiFailai) ~= sum(laukiamiKiekiai)
    error("Tiketi %d laiskai, gauta %d.", sum(laukiamiKiekiai), numel(visiFailai));
end
if sum(y == 0) ~= 4150 || sum(y == 1) ~= 1896
    error("Netiketas klasiu pasiskirstymas.");
end

fprintf("Patikrinti %d laiskai: %d normalus ir %d brukalo.\n", ...
    numel(y), sum(y == 0), sum(y == 1));

%% 3 etapas. Tapaties 57 pozymiu schemos pritaikymas

pirmasModelis = load(fullfile(modeliuAplankas, "hcvr_rf_42_cv.mat"), "paketas");
pozymiai = string(pirmasModelis.paketas.schema.pozymiai(:));
if numel(pozymiai) ~= 57
    error("Modelio schemoje tiketasi 57 pozymiu, gauta %d.", numel(pozymiai));
end

X = zeros(numel(visiFailai), numel(pozymiai));
for i = 1:numel(visiFailai)
    tekstas = nuskaitytiLaiska(visiFailai(i));
    X(i, :) = apskaiciuotiSpambasePozymius(tekstas, pozymiai);
    if mod(i, 250) == 0 || i == numel(visiFailai)
        fprintf("Pozymiai apskaiciuoti %d/%d laisku.\n", i, numel(visiFailai));
    end
end

if any(~isfinite(X), "all")
    error("Apskaiciuotuose pozymiuose yra nebaigtiniu reiksmiu.");
end

rowId = (0:numel(y)-1)';
failuVardai = strings(numel(visiFailai), 1);
for i = 1:numel(visiFailai)
    [~, vardas, pletinys] = fileparts(visiFailai(i));
    failuVardai(i) = string(vardas) + string(pletinys);
end

pozymiuLentele = [table(rowId, visosGrupes, failuVardai, y, ...
    'VariableNames', {'row_id', 'source_group', 'file_name', 'true_class'}), ...
    array2table(X, 'VariableNames', cellstr(pozymiai'))];
pozymiuFailas = fullfile(rezultatuAplankas, "spamassassin_features.csv");
writetable(pozymiuLentele, pozymiuFailas);

%% 4 etapas. Issaugotu modeliu isorinis testas

modeliuPavadinimai = ["Daugumos klase"; "Logistine regresija"; ...
    "SVM"; "Atsitiktinis miskas"; "HCVR-RF"];
modeliuVersijos = ["majority_42_full"; "lr_42_cv"; "svm_42_cv"; ...
    "rf_42_cv"; "hcvr_rf_42_cv"];

visosPrognozes = table;
visosMetrikos = table;
visiBalai = zeros(numel(y), numel(modeliuVersijos));
visosKlases = zeros(numel(y), numel(modeliuVersijos));

for i = 1:numel(modeliuVersijos)
    modelioFailas = fullfile(modeliuAplankas, modeliuVersijos(i) + ".mat");
    if ~isfile(modelioFailas)
        error("Modelio failas nerastas: %s", modelioFailas);
    end
    ikeltas = load(modelioFailas, "paketas");
    paketas = ikeltas.paketas;
    if ~isequal(string(paketas.schema.pozymiai(:)), pozymiai)
        error("Modelio %s pozymiu schema nesutampa.", modeliuVersijos(i));
    end

    laikmatis = tic;
    balai = prognozuotiBalus(paketas, X);
    klases = klasifikuotiBalus(paketas, balai);
    vertinimoLaikas = toc(laikmatis);
    m = skaiciuotiMetrikas(y, klases, balai);
    m.modelis = modeliuPavadinimai(i);
    m.model_version = modeliuVersijos(i);
    m.threshold = paketas.slenkstis;
    m.vertinimo_laikas_s = vertinimoLaikas;
    m.irasu_skaicius = numel(y);
    visosMetrikos = [visosMetrikos; struct2table(m, 'AsArray', true)]; %#ok<AGROW>

    prognozes = table(rowId, visosGrupes, failuVardai, ...
        repmat(modeliuPavadinimai(i), numel(y), 1), y, klases, balai, ...
        repmat(paketas.slenkstis, numel(y), 1), ...
        repmat(modeliuVersijos(i), numel(y), 1), ...
        'VariableNames', {'row_id', 'source_group', 'file_name', 'model', ...
        'true_class', 'class', 'score', 'threshold', 'model_version'});
    visosPrognozes = [visosPrognozes; prognozes]; %#ok<AGROW>
    visiBalai(:, i) = balai;
    visosKlases(:, i) = klases;
    fprintf("Patikrintas modelis %d/%d: %s\n", ...
        i, numel(modeliuVersijos), modeliuPavadinimai(i));
end

writetable(visosPrognozes, fullfile(rezultatuAplankas, ...
    "spamassassin_predictions.csv"));
writetable(visosMetrikos, fullfile(rezultatuAplankas, ...
    "spamassassin_metrics.csv"));

%% 5 etapas. Hipoteziu patikra naujame rinkinyje

[hipotezes, praleista] = porineSaviranka(y, visiBalai, 1000);
writetable(hipotezes, fullfile(rezultatuAplankas, ...
    "spamassassin_hypotheses.csv"));

%% 6 etapas. Auditas ir rezultatu suvestine

auditas = struct;
auditas.saltinis = bazineNuoroda;
auditas.rinkinys = "Apache SpamAssassin Public Corpus";
auditas.archyvai = cellstr(archyvai);
auditas.irasu_skaicius = numel(y);
auditas.normalus_laiskai = sum(y == 0);
auditas.brukalo_laiskai = sum(y == 1);
auditas.pozymiu_skaicius = size(X, 2);
auditas.modeliu_skaicius = numel(modeliuVersijos);
auditas.modeliai_permokyti = false;
auditas.slenksciai_pakeisti = false;
auditas.savirankos_bandymu = 1000;
auditas.savirankos_praleistu_imciu = praleista;
auditas.pozymiu_aprasymas = ...
    "48 zodziu dazniai, 6 simboliu dazniai ir 3 didziuju raidziu sekos rodikliai";
irasytiJson(fullfile(rezultatuAplankas, "spamassassin_audit.json"), auditas);

disp(visosMetrikos(:, {'modelis', 'precision', 'recall', 'fpr', ...
    'pr_auc', 'average_precision', 'cost_10', 'FP', 'FN', ...
    'vertinimo_laikas_s'}));
fprintf("\nIsorines hipotezes pagal 1000 porines savirankos bandymu:\n");
disp(hipotezes);
fprintf("\nIsorinis testas baigtas. Modeliai nebuvo permokyti.\n");
fprintf("Rezultatu aplankas: %s\n", rezultatuAplankas);

function tekstas = nuskaitytiLaiska(failas)
    fid = fopen(failas, "r", "n");
    if fid < 0
        error("Nepavyko atverti laisko: %s", failas);
    end
    valymas = onCleanup(@() fclose(fid));
    baitai = fread(fid, Inf, "*uint8");
    tekstas = char(baitai(:))';
end

function x = apskaiciuotiSpambasePozymius(tekstas, pozymiai)
    x = zeros(1, numel(pozymiai));
    mazosios = lower(tekstas);
    zodziai = regexp(mazosios, "[a-z0-9]+", "match");
    zodziuSkaicius = numel(zodziai);
    simboliuSkaicius = numel(tekstas);

    didziujuSekos = regexp(tekstas, "[A-Z]+", "match");
    if isempty(didziujuSekos)
        vidutinisIlgis = 0;
        ilgiausiaSeka = 0;
        didziujuSuma = 0;
    else
        sekuIlgiai = cellfun(@numel, didziujuSekos);
        vidutinisIlgis = mean(sekuIlgiai);
        ilgiausiaSeka = max(sekuIlgiai);
        didziujuSuma = sum(sekuIlgiai);
    end

    for j = 1:numel(pozymiai)
        pavadinimas = pozymiai(j);
        if startsWith(pavadinimas, "word_freq_")
            zodis = char(extractAfter(pavadinimas, "word_freq_"));
            if zodziuSkaicius > 0
                x(j) = 100 * sum(strcmp(zodziai, zodis)) / zodziuSkaicius;
            end
        elseif startsWith(pavadinimas, "char_freq_")
            simbolis = char(extractAfter(pavadinimas, "char_freq_"));
            if simboliuSkaicius > 0
                x(j) = 100 * sum(tekstas == simbolis) / simboliuSkaicius;
            end
        elseif pavadinimas == "capital_run_length_average"
            x(j) = vidutinisIlgis;
        elseif pavadinimas == "capital_run_length_longest"
            x(j) = ilgiausiaSeka;
        elseif pavadinimas == "capital_run_length_total"
            x(j) = didziujuSuma;
        else
            error("Nezinomas pozymis: %s", pavadinimas);
        end
    end
end

function balai = prognozuotiBalus(paketas, X)
    if paketas.tipas == "majority"
        balai = repmat(paketas.brukaloDalis, size(X, 1), 1);
        return;
    end
    X = pritaikytiParuosima(paketas.paruosimas, paketas.pozymiuKauke, X);
    [~, visiBalai] = predict(paketas.modelis, X);
    if paketas.tipas == "rf" || paketas.tipas == "hcvr_rf"
        klasiuPavadinimai = string(paketas.modelis.ClassNames);
        stulpelis = find(str2double(klasiuPavadinimai) == 1, 1);
    else
        stulpelis = find(paketas.modelis.ClassNames == 1, 1);
    end
    if isempty(stulpelis)
        error("Modelio isvestyje nerasta klases 1 balo.");
    end
    balai = visiBalai(:, stulpelis);
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

function klases = klasifikuotiBalus(paketas, balai)
    if paketas.sprendimoBud == "majority"
        klases = repmat(paketas.dazniausiaKlase, size(balai));
    elseif paketas.sprendimoBud == "always_zero"
        klases = zeros(size(balai));
    else
        klases = double(balai >= paketas.slenkstis);
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
    m.pr_auc = prAuc(y, balai);
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

function plotas = prAuc(y, balai)
    [~, ~, ~, plotas] = perfcurve(y, balai, 1, ...
        "XCrit", "reca", "YCrit", "prec");
end

function ap = vidutinisPreciziskumas(y, balai)
    [surikiuotiBalai, tvarka] = sort(balai, "descend");
    surikiuotaY = y(tvarka);
    teigiamuSkaicius = sum(y == 1);
    if teigiamuSkaicius == 0
        ap = NaN;
        return;
    end
    grupesPabaiga = [find(diff(surikiuotiBalai) ~= 0); numel(y)];
    sukauptiTeigiami = cumsum(surikiuotaY == 1);
    teigiamiGrupese = diff([0; sukauptiTeigiami(grupesPabaiga)]);
    preciziskumasGrupese = sukauptiTeigiami(grupesPabaiga) ./ grupesPabaiga;
    ap = sum((teigiamiGrupese / teigiamuSkaicius) .* preciziskumasGrupese);
end

function [hipotezes, praleista] = porineSaviranka(y, balai, bandymuSkaicius)
    neigiami = find(y == 0);
    teigiami = find(y == 1);
    skirtumai = nan(bandymuSkaicius, 2);
    praleista = 0;
    for b = 1:bandymuSkaicius
        indeksai = [neigiami(randi(numel(neigiami), numel(neigiami), 1)); ...
            teigiami(randi(numel(teigiami), numel(teigiami), 1))];
        try
            lr = prAuc(y(indeksai), balai(indeksai, 2));
            rf = prAuc(y(indeksai), balai(indeksai, 4));
            hcvr = prAuc(y(indeksai), balai(indeksai, 5));
            skirtumai(b, :) = [hcvr - lr, hcvr - rf];
        catch
            praleista = praleista + 1;
        end
    end
    skirtumai = skirtumai(all(isfinite(skirtumai), 2), :);
    if isempty(skirtumai)
        error("Nepavyko atlikti savirankos vertinimo.");
    end
    pilnasSkirtumas = [prAuc(y, balai(:, 5)) - prAuc(y, balai(:, 2)), ...
        prAuc(y, balai(:, 5)) - prAuc(y, balai(:, 4))];
    apatine = prctile(skirtumai, 2.5, 1);
    virsutine = prctile(skirtumai, 97.5, 1);
    hipoteze = ["H1"; "H2"];
    palyginimas = ["HCVR-RF - LR"; "HCVR-RF - RF"];
    pr_auc_skirtumas = pilnasSkirtumas';
    apatine_95 = apatine';
    virsutine_95 = virsutine';
    siekinys = repmat(0.01, 2, 1);
    siekinys_pasiektas = pr_auc_skirtumas >= siekinys;
    apatine_riba_teigiama = apatine_95 > 0;
    isvada = repmat("nepatvirtinta", 2, 1);
    isvada(siekinys_pasiektas & apatine_riba_teigiama) = "patvirtinta";
    hipotezes = table(hipoteze, palyginimas, pr_auc_skirtumas, ...
        apatine_95, virsutine_95, siekinys, siekinys_pasiektas, ...
        apatine_riba_teigiama, isvada);
end

function irasytiJson(failas, struktura)
    fid = fopen(failas, "w", "n", "UTF-8");
    if fid < 0
        error("Nepavyko sukurti JSON failo: %s", failas);
    end
    valymas = onCleanup(@() fclose(fid));
    fwrite(fid, jsonencode(struktura, "PrettyPrint", true), "char");
end
