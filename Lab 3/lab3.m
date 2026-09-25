%% 3 laboratorinis darbas. Spindulio tipo baziniu funkciju tinklas
% 1 iejimas -> 2 Gauso funkcijos -> 1 tiesinis isejimas.
clear; clc; close all;

%% 1. Mokymo duomenys
x = 0.1:1/22:1;
% x - 20 iejimo skaiciu, d - norimi atsakymai (ta pati formule kaip Lab 2).
d = (1 + 0.6*sin(2*pi*x/0.7) + 0.3*sin(2*pi*x))/2;

%% 2. Rankiniu budu parinkti centrai ir spinduliai
% c - varpo centras, r - jo plotis. Mokymo metu ju nekeiciame.
% Vienu metu palikite aktyvia tik viena C ir R reiksmiu eilute.
c1 = 0.10; c2 = 0.80; r1 = 0.09; r2 = 0.23;
%c1 = 0.20; c2 = 0.90; r1 = 0.17; r2 = 0.37;
%c1 = 0.15; c2 = 0.85; r1 = 0.12; r2 = 0.28;
%c1 = 0.25; c2 = 0.95; r1 = 0.20; r2 = 0.42;

% w1 ir w2 - Gauso funkciju svoriai, w0 - isejimo poslinkis.
w1 = 0;
w2 = 0;
w0 = 0;
w1Pries = w1;
w2Pries = w2;
w0Pries = w0;
eta = 0.03;                  % kiek keiciame svorius vienu zingsniu
epochos = 5000;              % kiek kartu pereiname visus 20 pavyzdziu

% Abieju Gauso neuronu atsakymai kiekvienam mokymo taskui.
F1 = exp(-(x-c1).^2/(2*r1^2));
F2 = exp(-(x-c2).^2/(2*r2^2));
% Issaugome klaidu ir svoriu kitima, kaip ankstesniuose laboratoriniuose.
mseIstorija = zeros(epochos+1, 1);
svoriuIstorija = zeros(epochos+1, 3);
yPries = w1*F1 + w2*F2 + w0;
mseIstorija(1) = mean((d-yPries).^2);
svoriuIstorija(1, :) = [w1, w2, w0];

%% 3. Mokymas: atsakymas -> klaida -> svoriu atnaujinimas
for epocha = 1:epochos
    for index = 1:length(x)
        % Tinklo atsakymas vienam pavyzdziui.
        y = w1*F1(index) + w2*F2(index) + w0;

        % Norimas atsakymas minus tinklo atsakymas.
        e = d(index) - y;

        % Ta pati svoriu atnaujinimo taisykle kaip Lab 1.
        w1 = w1 + eta*e*F1(index);
        w2 = w2 + eta*e*F2(index);
        w0 = w0 + eta*e;
    end
    % Po visos epochos tikriname atsakymus su naujais svoriais.
    yPagrindinis = w1*F1 + w2*F2 + w0;
    mseIstorija(epocha+1) = mean((d-yPagrindinis).^2);
    svoriuIstorija(epocha+1, :) = [w1, w2, w0];
end

%% 4. Patikra naujuose taskuose mokymo intervalo viduje
% 19 tarpiniu tasku nebuvo naudojami jokiu parametru mokymui.
xPatikra = (x(1:end-1) + x(2:end))/2;
dPatikra = (1 + 0.6*sin(2*pi*xPatikra/0.7) + 0.3*sin(2*pi*xPatikra))/2;
F1Patikra = exp(-(xPatikra-c1).^2/(2*r1^2));
F2Patikra = exp(-(xPatikra-c2).^2/(2*r2^2));
yPatikraPagr = w1*F1Patikra + w2*F2Patikra + w0;
msePatikraPagr = mean((dPatikra-yPatikraPagr).^2);

%% 5. Rezultatu lenteles
% MSE - klaidas pakeliame kvadratu ir apskaiciuojame ju vidurki.
parametruLentele = table(w1, w2, w0, c1, c2, r1, r2);
rezultatuLentele = table(x', d', yPagrindinis', (d-yPagrindinis)', ...
    'VariableNames', {'x','Norimas','TinkloAtsakas','Klaida'});
palyginimas = table(mseIstorija(end), msePatikraPagr, ...
    'VariableNames', {'MokymoMSE','PatikrosMSE'});
disp('GALUTINIAI PARAMETRAI'); disp(parametruLentele);
disp('20 MOKYMO TASKU REZULTATAI'); disp(rezultatuLentele);
disp('VIDUTINE KVADRATINE PAKLAIDA (MSE)');
fprintf('%-20s %14s %14s\n', 'Dalis', 'MokymoMSE', 'PatikrosMSE');
fprintf('%-20s %14.10f %14.10f\n', 'Pagrindine dalis', mseIstorija(end), msePatikraPagr);
fprintf('Mokymo intervalas: %.4f ... %.4f; pavyzdziu: %d.\n', ...
    x(1), x(end), numel(x));

%% 6. Kreiviu reiksmes grafikui
% Daugiau x tasku naudojame tik tam, kad kreives butu lygios.
xGausas = linspace(min([c1-4*r1, c2-4*r2]), max([c1+4*r1, c2+4*r2]), 801);
F1Gausas = exp(-(xGausas-c1).^2/(2*r1^2));
F2Gausas = exp(-(xGausas-c2).^2/(2*r2^2));
xAtsakas = linspace(x(1), x(end), 401);
dAtsakas = (1 + 0.6*sin(2*pi*xAtsakas/0.7) + 0.3*sin(2*pi*xAtsakas))/2;
F1Grafikas = exp(-(xAtsakas-c1).^2/(2*r1^2));
F2Grafikas = exp(-(xAtsakas-c2).^2/(2*r2^2));
yPries = w1Pries*F1Grafikas + w2Pries*F2Grafikas + w0Pries;
yPo = w1*F1Grafikas + w2*F2Grafikas + w0;

%% 7. Grafiko braizymas
% Raudona - pries mokyma, melyna - po, zalia - norimas atsakymas.
gausoLangas = figure('Name', 'Lab 3. Mokymo rezultatas', ...
    'Position', [120, 100, 1100, 650], 'Color', 'w');
hold on;
plot(xGausas, F1Gausas, '-', ...
    'Color', [0.65 0.75 0.88], 'LineWidth', 1.3, 'DisplayName', 'Gauso funkcija F1');
plot(xGausas, F2Gausas, '-', ...
    'Color', [0.88 0.73 0.60], 'LineWidth', 1.3, 'DisplayName', 'Gauso funkcija F2');
plot(xAtsakas, yPries, '-', ...
    'Color', [1 0 0], 'LineWidth', 1.5, 'DisplayName', 'Pries mokyma');
plot(xAtsakas, dAtsakas, '-', 'Color', [0 0.6 0], 'LineWidth', 2, 'DisplayName', 'Norimas atsakymas');
plot(xAtsakas, yPo, '-', ...
    'Color', [0 0.35 0.75], 'LineWidth', 2.5, 'DisplayName', 'Po mokymo');
plot(x, d, 'ko', 'MarkerSize', 4, 'MarkerFaceColor', 'w', 'HandleVisibility', 'off');
plot([c1 c1], [0 1], '-', 'Color', [0.65 0.75 0.88], 'HandleVisibility', 'off');
plot([c2 c2], [0 1], '-', 'Color', [0.88 0.73 0.60], 'HandleVisibility', 'off');
% Ties x = C-R Gauso funkcijos aukstis yra exp(-1/2).
% Atkarpa nuo C-R iki C parodo viena spinduli R.
aukstisR = exp(-0.5);
% Pagalbiniai apskritimai: centras (C, aukstisR), spindulys R.
kampas = linspace(0, 2*pi, 200);
plot(c1+r1*cos(kampas), aukstisR+r1*sin(kampas), 'k--', ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');
plot(c2+r2*cos(kampas), aukstisR+r2*sin(kampas), 'k--', ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');
plot([c1-r1 c1], [aukstisR aukstisR], 'o-', ...
    'Color', [0.3 0.4 0.55], 'LineWidth', 1.5, 'MarkerFaceColor', 'w', 'HandleVisibility', 'off');
plot([c2-r2 c2], [aukstisR aukstisR], 'o-', ...
    'Color', [0.55 0.4 0.3], 'LineWidth', 1.5, 'MarkerFaceColor', 'w', 'HandleVisibility', 'off');
text(c1-r1/2, aukstisR+0.04, sprintf('R1 = %.2f', r1), ...
    'HorizontalAlignment', 'center', 'Color', [0.3 0.4 0.55]);
text(c2-r2/2, aukstisR+0.04, sprintf('R2 = %.2f', r2), ...
    'HorizontalAlignment', 'center', 'Color', [0.55 0.4 0.3]);
text(c1, 1.04, sprintf('C1 = %.2f', c1), ...
    'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.3 0.4 0.55]);
text(c2, 1.04, sprintf('C2 = %.2f', c2), ...
    'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.55 0.4 0.3]);
hold off; grid on; box off;
axis equal;
xlim([0 1.3]); ylim([-0.08 1.15]);
xlabel('x'); ylabel('F(x) ir tinklo atsakas y');
title({'SBF tinklo mokymo rezultatas', ...
    'Tinklo atsakas rodomas mokymo intervale; blankios kreives - fiksuotos Gauso funkcijos'});
legend('Location', 'southoutside', 'NumColumns', 3);
set(gca, 'FontSize', 11, 'GridAlpha', 0.12);

