function rezultatai = ND1
%% 1. Duomenys
% Mantas Matusevicius, DISfm-26. Namu darbas Nr. 1.
% Ranka rasytu skaitmenu atpazinimas SVM metodu.
% Paleidimas: nd1Rezultatai = ND1;
% Reikalingas Statistics and Machine Learning Toolbox.
% Pavyzdys:
% https://scikit-learn.org/stable/auto_examples/classification/plot_digits_classification.html
clc; close all;
rng(42);

darboAplankas = fileparts(mfilename('fullpath'));
rezultatuAplankas = fullfile(darboAplankas, 'ND1_rezultatai');
if ~exist(rezultatuAplankas, 'dir'), mkdir(rezultatuAplankas); end

duomenuFailas = fullfile(darboAplankas, 'digits.csv');
if ~isfile(duomenuFailas)
    nuoroda = ['https://raw.githubusercontent.com/scikit-learn/' ...
        'scikit-learn/1.9.1/sklearn/datasets/data/digits.csv.gz'];
    archyvas = websave(fullfile(darboAplankas, 'digits.csv.gz'), nuoroda);
    gunzip(archyvas, darboAplankas);
end

duomenys = readmatrix(duomenuFailas);
assert(isequal(size(duomenys), [1797 65]), ...
    'Duomenu lentele turi buti 1797 x 65 dydzio.');
P = duomenys(:, 1:64);
T = duomenys(:, 65);

%% 2. Mokymo ir testavimo duomenys
% Pirmi 898 vaizdai naudojami mokymui, like 899 - testavimui.
mokymoP = P(1:898, :);
mokymoT = T(1:898);
testoP = P(899:end, :);
testoT = T(899:end);
testoKiekis = length(testoT);

%% 3. Mokymo imciu paruosimas
% Kiekvienos klases vaizdai sumaisomi atskirai.
% Taip mazesnese imtyse lieka panasus visu skaitmenu kiekis.
klasiuIndeksai = cell(10, 1);
for skaitmuo = 0:9
    indeksai = find(mokymoT == skaitmuo);
    klasiuIndeksai{skaitmuo+1} = indeksai(randperm(length(indeksai)));
end

atrankosEile = zeros(898, 1);
vieta = 0;
for eilute = 1:max(cellfun(@length, klasiuIndeksai))
    for klase = 1:10
        if eilute <= length(klasiuIndeksai{klase})
            vieta = vieta + 1;
            atrankosEile(vieta) = klasiuIndeksai{klase}(eilute);
        end
    end
end

%% 4. SVM modeliu mokymas
mokymoKiekiai = [100; 300; 600; 898];
teisingai = zeros(4, 1);
klaidos = zeros(4, 1);
tikslumas = zeros(4, 1);
prognozes = zeros(testoKiekis, 4);
modeliai = cell(4, 1);
mokymoIndeksai = cell(4, 1);

% Gauso branduolio mastelis sqrt(1000) atitinka gamma = 0.001.
svm = templateSVM('KernelFunction', 'gaussian', ...
    'KernelScale', sqrt(1000), 'BoxConstraint', 1, ...
    'Standardize', false);

for bandymas = 1:4
    if bandymas == 4
        indeksai = (1:898)';
    else
        indeksai = atrankosEile(1:mokymoKiekiai(bandymas));
    end

    mokymoIndeksai{bandymas} = indeksai;
    modeliai{bandymas} = fitcecoc(mokymoP(indeksai, :), ...
        mokymoT(indeksai), 'Learners', svm, ...
        'Coding', 'onevsone', 'ClassNames', (0:9)');
    prognozes(:, bandymas) = predict(modeliai{bandymas}, testoP);
    teisingai(bandymas) = sum(prognozes(:, bandymas) == testoT);
    klaidos(bandymas) = testoKiekis - teisingai(bandymas);
    tikslumas(bandymas) = 100 * teisingai(bandymas) / testoKiekis;

    fprintf(['Mokymo vaizdai: %d | Teisingi: %d | ' ...
        'Klaidos: %d | Tikslumas: %.2f%%\n'], ...
        mokymoKiekiai(bandymas), teisingai(bandymas), ...
        klaidos(bandymas), tikslumas(bandymas));
end

palyginimas = table(mokymoKiekiai, repmat(testoKiekis, 4, 1), ...
    teisingai, klaidos, tikslumas, 'VariableNames', ...
    {'Mokymo_vaizdai', 'Testavimo_vaizdai', 'Teisingi_atsakymai', ...
    'Klaidos', 'Tikslumas_proc'});
disp(palyginimas);

%% 5. Klaidu matrica
klaiduMatrica = confusionmat(testoT, prognozes(:, 4), 'Order', (0:9)');
figure('Name', 'ND1 - Klaidu matrica', 'Color', 'w', ...
    'Position', [80 80 740 620]);
confusionchart(klaiduMatrica, string(0:9));
title(sprintf('MATLAB SVM: %d/899 (%.2f%%)', teisingai(4), tikslumas(4)));
exportgraphics(gcf, fullfile(rezultatuAplankas, ...
    'klaidu_matrica.png'), 'Resolution', 180);

%% 6. Atpazinimo pavyzdziai
% Virsuje rodomi keturi teisingi, apacioje - keturi klaidingi atsakymai.
geri = find(prognozes(:, 4) == testoT, 4);
blogi = find(prognozes(:, 4) ~= testoT, 4);
pavyzdziuIndeksai = [geri; blogi];

figure('Name', 'ND1 - Atpazinimo pavyzdziai', 'Color', 'w', ...
    'Position', [100 100 960 440]);
tiledlayout(2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:length(pavyzdziuIndeksai)
    i = pavyzdziuIndeksai(k);
    nexttile;
    imagesc(reshape(testoP(i, :), 8, 8)', [0 16]);
    axis image off;
    if testoT(i) == prognozes(i, 4)
        spalva = [0.086 0.451 0.169];
    else
        spalva = [0.769 0.125 0.149];
    end
    title(sprintf('Tikrasis: %d | Atsakymas: %d', ...
        testoT(i), prognozes(i, 4)), 'Color', spalva);
end
colormap(gray);
exportgraphics(gcf, fullfile(rezultatuAplankas, ...
    'atpazinimo_pavyzdziai.png'), 'Resolution', 180);

%% 7. Mokymo duomenu kiekio palyginimas
figure('Name', 'ND1 - Mokymo duomenu kiekis', 'Color', 'w', ...
    'Position', [120 120 820 420]);
plot(mokymoKiekiai, tikslumas, '-o', 'LineWidth', 2);
grid on;
xlabel('Mokymo vaizdu skaicius');
ylabel('Tikslumas (%)');
ylim([0 100]);
title('Visuose bandymuose tie patys 899 testavimo vaizdai');
for k = 1:4
    text(mokymoKiekiai(k), tikslumas(k)-5, ...
        sprintf('%.2f%%', tikslumas(k)), 'HorizontalAlignment', 'center');
end
exportgraphics(gcf, fullfile(rezultatuAplankas, ...
    'mokymo_kiekio_itaka.png'), 'Resolution', 180);

%% 8. Rezultatu issaugojimas
writetable(palyginimas, fullfile(rezultatuAplankas, 'palyginimas.csv'));
rezultatai = struct('matlabVersion', version, 'toolboxes', {ver}, ...
    'mokymoKiekiai', mokymoKiekiai, 'testSize', testoKiekis, ...
    'teisingiAtsakymai', teisingai, 'klaiduSkaicius', klaidos, ...
    'tikslumas', tikslumas, 'confusionMatrix', klaiduMatrica, ...
    'seed', 42);

failas = fopen(fullfile(rezultatuAplankas, 'rezultatai.json'), ...
    'w', 'n', 'UTF-8');
fprintf(failas, '%s', jsonencode(rezultatai));
fclose(failas);

save(fullfile(rezultatuAplankas, 'modeliai_ir_prognozes.mat'), ...
    'modeliai', 'prognozes', 'testoT', 'mokymoIndeksai', ...
    'palyginimas', 'rezultatai', 'pavyzdziuIndeksai');
copyfile([mfilename('fullpath') '.m'], ...
    fullfile(rezultatuAplankas, 'ND1.m'));
zip(fullfile(darboAplankas, 'ND1_rezultatai.zip'), ...
    'ND1_rezultatai', darboAplankas);
fprintf('Rezultatai issaugoti: %s\n', rezultatuAplankas);
end
