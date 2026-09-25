%% 1. Duomenys
% Mantas Matusevicius, DISfm-26. Laboratorinis darbas Nr. 4.
delete(findall(groot, 'Type', 'figure', 'Name', 'Skaitmenu atpazinimo rezultatai'));
clear; clc; close all;
rng(4);

mokymoAtsakymai = repmat(1:7, 1, 4);
testoAtsakymai = [3 2 1 7 1 2 3, 3 3 4 5 6 7 1, ...
    7 6 5 4 3 2 1, 6 5 3 1 2 4 3];

%% 2. Skaitmenu iskirpimas ir 35 pozymiai
[P, mokymoVaizdai] = paruostiVaizda('mokymas.jpg');
[Ptest, testoVaizdai] = paruostiVaizda('testas.jpg');
assert(size(P,2) == numel(mokymoAtsakymai), 'Mokymo skaitmenu kiekis neatitinka atsakymu. Patikrinkite aptikimo grafika.');
assert(size(Ptest,2) == numel(testoAtsakymai), 'Testo skaitmenu kiekis neatitinka atsakymu. Patikrinkite aptikimo grafika.');
rodytiSkaitmenis(mokymoVaizdai, mokymoAtsakymai, 'Mokymo skaitmenys');
rodytiSkaitmenis(testoVaizdai, testoAtsakymai, 'Testo skaitmenys ir tikrosios klases');
T = repmat(eye(7), 1, 4);

%% 3. RBF tinklas su 13 neuronu
% 100 virsija neuronu skaiciu, todel tarpinis mokymo grafikas neatnaujinamas.
rbf13 = newrb(P, T, 0, 1, 13, 100);
[~, atsakymai13] = max(rbf13(Ptest), [], 1);

%% 4. RBF tinklas su 7 neuronais
rbf7 = newrb(P, T, 0, 1, 7, 100);
[~, atsakymai7] = max(rbf7(Ptest), [], 1);

%% 5. Rezultatu palyginimas
% Testo pavyzdziai nenaudojami tinklu mokymui.
prognozes = [atsakymai13; atsakymai7];
teisingai = sum(prognozes == testoAtsakymai, 2);
tikslumas = 100 * teisingai / numel(testoAtsakymai);
palyginimas = table(["RBF 13"; "RBF 7"], ...
    [rbf13.layers{1}.size; rbf7.layers{1}.size], ...
    teisingai, tikslumas, 'VariableNames', ...
    {'Tinklas', 'Neuronai', 'Teisingai', 'Tikslumas_proc'});
disp(palyginimas);
rezultatai = table((1:28)', testoAtsakymai', atsakymai13', ...
    atsakymai7', 'VariableNames', ...
    {'Nr', 'Tikras', 'RBF13', 'RBF7'});
disp(rezultatai);
figure('Name', 'Tinklu palyginimas');
bar(tikslumas); ylim([0 100]); grid on;
xticks(1:2); xticklabels({'RBF 13', 'RBF 7'});
ylabel('Tikslumas, %'); title('28 atskiru testo skaitmenu atpazinimas');

%% 6. Rezultatu issaugojimas MATLAB Drive
save('lab4_rezultatai.mat', 'P', 'Ptest', 'T', 'testoAtsakymai', 'rbf13', 'rbf7', 'palyginimas', 'rezultatai');
writetable(palyginimas, 'lab4_palyginimas.csv');
writetable(rezultatai, 'lab4_prognozes.csv');
imwrite(imtile(mokymoVaizdai, 'GridSize', [4 7]), 'mokymo_patikra.png');
imwrite(imtile(testoVaizdai, 'GridSize', [4 7]), 'testo_patikra.png');

%% 7. Spalvota atpazinimo rezultatu lentele
rezultatuLangas = uifigure('Name', 'Skaitmenu atpazinimo rezultatai', ...
    'Position', [100 40 560 860]);
isdestymas = uigridlayout(rezultatuLangas, [2 1]);
isdestymas.RowHeight = {32, '1x'};
uilabel(isdestymas, 'Text', ...
    'Zalia - teisingai, raudona - klaida. Lyginama su Tikras.', ...
    'FontSize', 13);
spalvotaLentele = uitable(isdestymas, 'Data', rezultatai, ...
    'ColumnName', {'Nr', 'Tikras', 'RBF 13', 'RBF 7'}, ...
    'ColumnEditable', false, 'RowName', [], ...
    'ColumnWidth', {60, 90, 130, 130}, 'FontSize', 14);
zaliasStilius = uistyle('BackgroundColor', [0.72 0.91 0.72], ...
    'FontColor', [0.08 0.25 0.08]);
raudonasStilius = uistyle('BackgroundColor', [1.00 0.72 0.72], ...
    'FontColor', [0.45 0.05 0.05]);
for tinkloNr = 1:2
    teisingi = find(prognozes(tinkloNr,:) == testoAtsakymai);
    klaidingi = find(prognozes(tinkloNr,:) ~= testoAtsakymai);
    if ~isempty(teisingi)
        addStyle(spalvotaLentele, zaliasStilius, 'cell', ...
            [teisingi(:), repmat(tinkloNr+2, numel(teisingi), 1)]);
    end
    if ~isempty(klaidingi)
        addStyle(spalvotaLentele, raudonasStilius, 'cell', ...
            [klaidingi(:), repmat(tinkloNr+2, numel(klaidingi), 1)]);
    end
end

%% Vietines funkcijos
function [pozymiai, skaitmenys] = paruostiVaizda(failas)
    vaizdas = imread(failas);
    info = imfinfo(failas);
    if isfield(info, 'Orientation')
        if info.Orientation == 6, vaizdas = rot90(vaizdas, -1); end
        if info.Orientation == 8, vaizdas = rot90(vaizdas, 1); end
        if info.Orientation == 3, vaizdas = rot90(vaizdas, 2); end
    end
    if size(vaizdas, 3) == 3, vaizdas = rgb2gray(vaizdas); end
    pilkas = im2double(imresize(vaizdas, [NaN 800]));
    % Didziausia sviesi sritis yra popieriaus lapas.
    lapas = imfill(imbinarize(pilkas), 'holes');
    lapas = bwareafilt(lapas, 1);
    lapas = imerode(lapas, strel('disk', 15, 0));
    rasalas = imbothat(pilkas, strel('disk', 9, 0));
    slenkstis = max(0.015, graythresh(rasalas(lapas)));
    dvejetainis = (rasalas > slenkstis) & lapas;
    dvejetainis = bwareaopen(dvejetainis, 3);
    % Sujungiami to paties skaitmens nutruke piestuko potepiai.
    sujungti = imdilate(dvejetainis, strel('disk', 3, 0));
    sujungti = bwareaopen(sujungti, 60);
    sritys = regionprops(sujungti, 'BoundingBox', 'Centroid');
    ribos = vertcat(sritys.BoundingBox);
    tinkami = ribos(:,3) >= 8 & ribos(:,4) >= 20;
    sritys = sritys(tinkami);
    if isempty(sritys), error('Skaitmenu nerasta: %s', failas); end
    ribos = vertcat(sritys.BoundingBox);
    centrai = vertcat(sritys.Centroid);
    [~, tvarka] = sort(centrai(:,2));
    % Eilutes atskiriamos pagal tarpus tarp simboliu centru.
    tarpas = 0.6 * median(ribos(:,4));
    eilutes = cumsum([1; diff(centrai(tvarka,2)) > tarpas]);
    seka = [];
    for eilute = 1:max(eilutes)
        indeksai = tvarka(eilutes == eilute);
        [~, k] = sort(centrai(indeksai,1));
        seka = [seka; indeksai(k)]; %#ok<AGROW>
    end
    kiekis = numel(seka);
    fprintf('%s: automatiskai rasta %d skaitmenu, %d eilutes.\n', failas, kiekis, max(eilutes));
    pozymiai = zeros(35, kiekis);
    skaitmenys = cell(1, kiekis);
    figure('Name', ['Automatinis aptikimas: ' failas]);
    imshow(pilkas); hold on;
    for nr = 1:kiekis
        riba = ribos(seka(nr),:);
        rectangle('Position', riba, 'EdgeColor', 'r');
        text(riba(1), riba(2)-8, num2str(nr), 'Color', 'r');
        fragmentas = imcrop(dvejetainis, riba);
        [y, x] = find(fragmentas);
        fragmentas = fragmentas(min(y):max(y), min(x):max(x));
        simbolis = imresize(double(fragmentas), [70 50], 'nearest');
        skaitmenys{nr} = simbolis;
        for m = 1:7
            for n = 1:5
                dalis = simbolis((m-1)*10+(1:10), (n-1)*10+(1:10));
                pozymiai((m-1)*5+n, nr) = mean(dalis(:));
            end
        end
    end
    hold off;
end

function rodytiSkaitmenis(vaizdai, atsakymai, pavadinimas)
figure('Name', pavadinimas);
tiledlayout(4, 7, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:numel(vaizdai)
    nexttile; imshow(vaizdai{k});
    title(sprintf('%d: %d', k, atsakymai(k)));
end
sgtitle(pavadinimas);
end
