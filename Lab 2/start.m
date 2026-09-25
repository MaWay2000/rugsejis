%% 2 laboratorinis darbas. Daugiasluoksnio perceptrono mokymas
% 1 iejimas -> 5 sigmoidiniai neuronai -> 1 tiesinis isejimas
% Atgalinio sklidimo algoritmas realizuotas be newff, train ir sim funkciju.
clear; clc; close all;
rng(12);                       % tie patys pradiniai svoriai kiekviena karta

%% 20 mokymo pavyzdziu
x = linspace(0, 1, 20);
d = (1 + 0.6*sin(2*pi*x/0.7) + 0.3*sin(2*pi*x))/2;

%% Tinklo pradines reiksmes
neuronai = 5;
eta = 0.3;                    % mokymosi zingsnis pagal teorijos pavyzdi
maxEpochs = 100000;
tikslas = 1e-5;

% Svoriai ir poslinkiai uzrasyti atskirai, kad matytusi kiekvienas rysys
w11 = randn; w12 = randn; w13 = randn; w14 = randn; w15 = randn;
b11 = randn; b12 = randn; b13 = randn; b14 = randn; b15 = randn;
w21 = randn; w22 = randn; w23 = randn; w24 = randn; w25 = randn;
b2 = randn;                   % isejimo neurono poslinkis
mseIstorija = zeros(1, maxEpochs);

%% Mokymas po viena pavyzdi (online / stochastic Backpropagation)
for epocha = 1:maxEpochs
    for index = 1:length(x)
        % Tiesioginis sklidimas
        v11 = w11*x(index) + b11;
        v12 = w12*x(index) + b12;
        v13 = w13*x(index) + b13;
        v14 = w14*x(index) + b14;
        v15 = w15*x(index) + b15;

        y11 = 1 / (1 + exp(-v11));
        y12 = 1 / (1 + exp(-v12));
        y13 = 1 / (1 + exp(-v13));
        y14 = 1 / (1 + exp(-v14));
        y15 = 1 / (1 + exp(-v15));

        y = w21*y11 + w22*y12 + w23*y13 + w24*y14 + w25*y15 + b2;

        % Paklaida
        e = d(index) - y;

        % Pasleptojo sluoksnio delta skaiciuojama su senais w2 svoriais
        delta11 = y11*(1-y11)*w21*e;
        delta12 = y12*(1-y12)*w22*e;
        delta13 = y13*(1-y13)*w23*e;
        delta14 = y14*(1-y14)*w24*e;
        delta15 = y15*(1-y15)*w25*e;

        % Isejimo sluoksnio svoriu atnaujinimas
        w21 = w21 + eta*e*y11;
        w22 = w22 + eta*e*y12;
        w23 = w23 + eta*e*y13;
        w24 = w24 + eta*e*y14;
        w25 = w25 + eta*e*y15;
        b2 = b2 + eta*e;

        % Pasleptojo sluoksnio svoriu atnaujinimas
        w11 = w11 + eta*delta11*x(index); b11 = b11 + eta*delta11;
        w12 = w12 + eta*delta12*x(index); b12 = b12 + eta*delta12;
        w13 = w13 + eta*delta13*x(index); b13 = b13 + eta*delta13;
        w14 = w14 + eta*delta14*x(index); b14 = b14 + eta*delta14;
        w15 = w15 + eta*delta15*x(index); b15 = b15 + eta*delta15;
    end

    % MSE skaiciuojama po visos epochos su atnaujintais koeficientais
    % Vektoriai naudojami tik bendram visu tasku atsakui apskaiciuoti
    w1 = [w11; w12; w13; w14; w15];
    b1 = [b11; b12; b13; b14; b15];
    w2 = [w21, w22, w23, w24, w25];
    yMokymo = tinkloAtsakas(x, w1, b1, w2, b2);
    mseIstorija(epocha) = mean((d-yMokymo).^2);
    if mseIstorija(epocha) <= tikslas
        mseIstorija = mseIstorija(1:epocha);
        break;
    end
end

%% Rezultatai tankiame tinklelyje
xTest = linspace(0, 1, 401);
dTest = (1 + 0.6*sin(2*pi*xTest/0.7) + 0.3*sin(2*pi*xTest))/2;
yTest = tinkloAtsakas(xTest, w1, b1, w2, b2);
testMSE = mean((dTest-yTest).^2);

fprintf('Epochu skaicius: %d\n', epocha);
fprintf('Mokymo MSE: %.8g\n', mseIstorija(end));
fprintf('Patikros MSE: %.8g\n', testMSE);

%% Visu 20 mokymo pavyzdziu rezultatu lentele
lentelesIndeksai = 1:length(x);
rezultatuLentele = table((1:length(lentelesIndeksai))', x(lentelesIndeksai)', ...
    d(lentelesIndeksai)', yMokymo(lentelesIndeksai)', ...
    (d(lentelesIndeksai)-yMokymo(lentelesIndeksai))', ...
    'VariableNames', {'Nr', 'x', 'Norimas_d', 'Tinklo_y', 'Klaida'});
disp('w1 ='); disp(w1);
disp('b1 ='); disp(b1);
disp('w2 ='); disp(w2);
disp('b2 ='); disp(b2);

figure('Color', 'w');
subplot(2,1,1);
plot(xTest, dTest, 'k-', 'LineWidth', 1.5); hold on;
plot(xTest, yTest, 'r--', 'LineWidth', 1.5);
plot(x, d, 'bo', 'MarkerFaceColor', 'b');
grid on; xlabel('x'); ylabel('y');
legend('Norimas atsakas', 'Tinklo atsakas', '20 mokymo tasku', ...
    'Location', 'best');
title(sprintf('Tinklas 1-5-1, patikros MSE = %.3g', testMSE));

subplot(2,1,2);
semilogy(1:length(mseIstorija), mseIstorija, 'LineWidth', 1.3);
grid on; xlabel('Epocha'); ylabel('MSE');
title('Mokymo paklaidos kitimas');

klaidosTekstas = arrayfun(@(v) sprintf('%.8f', v), ...
    rezultatuLentele.Klaida, 'UniformOutput', false);
lenteleDuomenys = [num2cell([rezultatuLentele.Nr, rezultatuLentele.x, ...
    rezultatuLentele.Norimas_d, rezultatuLentele.Tinklo_y]), klaidosTekstas];
figure('Name', '20 mokymo pavyzdziu', 'Color', 'w', ...
    'Position', [250 100 750 600]);
uitable('Parent', gcf, 'Data', lenteleDuomenys, ...
    'ColumnName', {'Nr', 'x', 'd', 'y', 'd-y'}, ...
    'RowName', [], ...
    'Units', 'normalized', 'Position', [0.05 0.08 0.90 0.82], ...
    'ColumnWidth', {50, 120, 140, 140, 180});
annotation(gcf, 'textbox', [0.05 0.92 0.90 0.05], ...
    'String', '20 mokymo pavyzdziu', 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold');

%% Tinklo strukturos piesinys
figure('Name', 'Tinklo struktura', 'Color', 'w', ...
    'Position', [150 150 900 560]);
hold on; axis([-0.45 2.45 -0.55 4.55]); axis off;

inputPos = [0, 2];
hiddenY = linspace(0.4, 3.6, neuronai);
outputPos = [2, 2];

% Jungtys: vienas iejimas sujungtas su visais pasleptaisiais neuronais,
% o kiekvienas pasleptasis neuronas - su isejimo neuronu.
for k = 1:neuronai
    plot([inputPos(1), 1], [inputPos(2), hiddenY(k)], ...
        '-', 'Color', [0.60 0.68 0.78], 'LineWidth', 1.4);
    plot([1, outputPos(1)], [hiddenY(k), outputPos(2)], ...
        '-', 'Color', [0.60 0.68 0.78], 'LineWidth', 1.4);
end

% Neuronai
scatter(inputPos(1), inputPos(2), 1800, [0.25 0.55 0.90], ...
    'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.4);
scatter(ones(1, neuronai), hiddenY, 1500, [0.95 0.63 0.20], ...
    'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
scatter(outputPos(1), outputPos(2), 1800, [0.35 0.75 0.45], ...
    'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.4);

text(inputPos(1), inputPos(2), 'x', 'HorizontalAlignment', 'center', ...
    'FontSize', 18, 'FontWeight', 'bold', 'Color', 'w');
for k = 1:neuronai
    text(1, hiddenY(k), '\sigma', 'Interpreter', 'tex', ...
        'HorizontalAlignment', 'center', 'FontSize', 19, ...
        'FontWeight', 'bold');
    text(1.17, hiddenY(k), sprintf('y_%d', k), 'FontSize', 11);
end
text(outputPos(1), outputPos(2), 'y', 'HorizontalAlignment', 'center', ...
    'FontSize', 18, 'FontWeight', 'bold', 'Color', 'w');

% Sluoksniu ir parametru paaiskinimai
text(0, -0.22, 'Iejimas', 'HorizontalAlignment', 'center', ...
    'FontSize', 13, 'FontWeight', 'bold');
text(1, -0.22, '5 sigmoidiniai neuronai', ...
    'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold');
text(2, -0.22, 'Tiesinis isejimas', 'HorizontalAlignment', 'center', ...
    'FontSize', 13, 'FontWeight', 'bold');
text(0.42, 4.15, 'w_{11}...w_{15}, b_{11}...b_{15}', 'Interpreter', 'tex', ...
    'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [0.15 0.30 0.55]);
text(1.58, 4.15, 'w_{21}...w_{25}, b_2', 'Interpreter', 'tex', ...
    'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [0.15 0.30 0.55]);
title({'Daugiasluoksnio perceptrono struktura (1-5-1)', ...
    'Pasleptas sluoksnis: sigmoidinis; isejimas: tiesinis'}, ...
    'FontSize', 15);

%% Vietine funkcija tinklo atsakui skaiciuoti
function y = tinkloAtsakas(x, w1, b1, w2, b2)
    y1 = 1 ./ (1 + exp(-(w1*x + b1)));
    y = w2*y1 + b2;
end
