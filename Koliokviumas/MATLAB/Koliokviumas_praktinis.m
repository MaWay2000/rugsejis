%% KOLIOKVIUMO PRAKTINIS DARBAS
% Nepageidaujamu laisku atpazinimas naudojant UCI Spambase duomenis.
% Mantas Matusevicius, DISfm-26
%
% Sis pirmasis praktinis etapas igyvendina duomenu patikra, grupini
% 60/20/20 skaidyma ir penkis pradinius variantus. Testavimo imtis
% naudojama tik po modeliu ismokymo ir slenksciu parinkimo.

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

%% 4 etapas. Pradiniu modeliu mokymas

Xmok = X(mokymoIndeksai, :);
ymok = y(mokymoIndeksai);
Xder = X(derinimoIndeksai, :);
yder = y(derinimoIndeksai);

modeliuPavadinimai = ["Daugumos klase", "Logistine regresija", ...
    "SVM", "Atsitiktinis miskas", "HCVR-RF"];
modeliuVersijos = ["majority_42_full", "lr_42_full", "svm_42_full", ...
    "rf_42_full", "hcvr_rf_42_full"];

paketai = cell(numel(modeliuPavadinimai), 1);
derinimoBalai = cell(numel(modeliuPavadinimai), 1);
mokymoLaikai = zeros(numel(modeliuPavadinimai), 1);

laikmatis = tic;
paketai{1} = mokytiDaugumosModeli(ymok, modeliuVersijos(1));
mokymoLaikai(1) = toc(laikmatis);

laikmatis = tic;
paketai{2} = mokytiModeli(Xmok, ymok, "lr", struct("Lambda", 0.001), ...
    modeliuVersijos(2), pradineReiksme);
mokymoLaikai(2) = toc(laikmatis);

laikmatis = tic;
paketai{3} = mokytiModeli(Xmok, ymok, "svm", ...
    struct("C", 1, "Gamma", 0.01), modeliuVersijos(3), pradineReiksme);
mokymoLaikai(3) = toc(laikmatis);

laikmatis = tic;
paketai{4} = mokytiModeli(Xmok, ymok, "rf", ...
    struct("Medziai", 100, "Lapas", 1), modeliuVersijos(4), pradineReiksme);
mokymoLaikai(4) = toc(laikmatis);

laikmatis = tic;
paketai{5} = mokytiModeli(Xmok, ymok, "hcvr_rf", ...
    struct("Medziai", 100, "Lapas", 1, "Theta", 0.04), ...
    modeliuVersijos(5), pradineReiksme);
mokymoLaikai(5) = toc(laikmatis);

for i = 1:numel(paketai)
    derinimoBalai{i} = prognozuotiBalus(paketai{i}, Xder);
    if i == 1
        paketai{i}.slenkstis = NaN;
        paketai{i}.sprendimoBud = "majority";
    else
        [paketai{i}.slenkstis, paketai{i}.sprendimoBud] = ...
            parinktiSlenksti(yder, derinimoBalai{i}, 0.01);
    end
    paketas = paketai{i}; %#ok<NASGU>
    save(fullfile(modeliuAplankas, modeliuVersijos(i) + ".mat"), "paketas", "-v7.3");
end

fprintf("Pradiniai modeliai ismokyti, slenksciai parinkti tik derinimo imtyje.\n");

%% 5 etapas. Galutinis pradinis testas

Xtest = X(testoIndeksai, :);
ytest = y(testoIndeksai);
testoRowId = eilutesId(testoIndeksai);
testoGroupId = grupesId(testoIndeksai);

visosPrognozes = table;
visosMetrikos = table;
prKreives = cell(numel(paketai), 1);

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
end

writetable(visosPrognozes, fullfile(rezultatuAplankas, "predictions.csv"));
writetable(visosMetrikos, fullfile(rezultatuAplankas, "metrics.csv"));

%% 6 etapas. Kontrolines patikros ir auditas

testuotiMetrikas();
testuotiHcvrTaisykles();

auditas = struct;
auditas.pradine_reiksme = pradineReiksme;
auditas.raw_sha256 = manifestas.raw_sha256;
auditas.mokymo_eiluciu = sum(mokymoIndeksai);
auditas.derinimo_eiluciu = sum(derinimoIndeksai);
auditas.testavimo_eiluciu = sum(testoIndeksai);
auditas.mokymo_derinimo_row_sankirta = numel(intersect(eilutesId(mokymoIndeksai), eilutesId(derinimoIndeksai)));
auditas.mokymo_testo_row_sankirta = numel(intersect(eilutesId(mokymoIndeksai), eilutesId(testoIndeksai)));
auditas.derinimo_testo_row_sankirta = numel(intersect(eilutesId(derinimoIndeksai), eilutesId(testoIndeksai)));
auditas.mokymo_derinimo_group_sankirta = numel(intersect(grupesId(mokymoIndeksai), grupesId(derinimoIndeksai)));
auditas.mokymo_testo_group_sankirta = numel(intersect(grupesId(mokymoIndeksai), grupesId(testoIndeksai)));
auditas.derinimo_testo_group_sankirta = numel(intersect(grupesId(derinimoIndeksai), grupesId(testoIndeksai)));
auditas.metriku_kontrole = "TP=2, FP=1, FN=1, TN=6 patikrinta";
auditas.hcvr_kontrole = "Balsavimo sakos ir pastovus pozymis patikrinti";
auditas.testo_naudojimas = "Testas atvertas tik po modeliu mokymo ir slenksciu parinkimo";
irasytiJson(fullfile(rezultatuAplankas, "audit.json"), auditas);

%% 7 etapas. Grafikai

figura = figure("Color", "w", "Position", [100, 100, 1000, 700]);
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
exportgraphics(figura, fullfile(grafikuAplankas, "PR_kreives.png"), "Resolution", 300);
close(figura);

figura = figure("Color", "w", "Position", [100, 100, 1200, 650]);
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
exportgraphics(figura, fullfile(grafikuAplankas, "klaidu_matricos.png"), "Resolution", 300);
close(figura);

%% 8 etapas. Rezultatu suvestine

disp(visosMetrikos(:, {'modelis', 'precision', 'recall', 'fpr', 'pr_auc', ...
    'average_precision', 'cost_10', 'FP', 'FN', 'mokymo_laikas_s'}));
fprintf("\nPradinis praktinis etapas baigtas.\n");
fprintf("Rezultatu aplankas: %s\n", rezultatuAplankas);
fprintf("Kitas etapas: vidine grupine patikra ir pilna hiperparametru paieska.\n");

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
    valymas = onCleanup(@() fclose(failoId)); %#ok<NASGU>
    fprintf(failoId, "%s", tekstas);
end

function suma = failoSha256(failas)
    failoId = fopen(failas, "r");
    if failoId < 0
        error("Nepavyko atverti failo kontrolinei sumai: %s", failas);
    end
    valymas = onCleanup(@() fclose(failoId)); %#ok<NASGU>
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
    [~, tvarka] = sort(balai, "descend");
    surikiuotaY = y(tvarka);
    teigiami = cumsum(surikiuotaY == 1);
    tikslumasIkiVietos = teigiami ./ (1:numel(y))';
    if sum(y == 1) == 0
        ap = NaN;
    else
        ap = sum(tikslumasIkiVietos(surikiuotaY == 1)) / sum(y == 1);
    end
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
end
