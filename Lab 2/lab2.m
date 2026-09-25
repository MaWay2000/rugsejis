%% IS laboratorinis darbas Nr. 2: daugiasluoksnis perceptronas
% Paleidimas: MATLAB aplanke atidarykite si faila ir spauskite Run.
% Nereikia Deep Learning Toolbox. Vietines funkcijos yra failo pabaigoje.
clear; clc; close all;
rng(12, 'twister');
outDir = fullfile(fileparts(mfilename('fullpath')), 'lab2_rezultatai');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% 1. Vieno kintamojo funkcijos aproksimavimas (1-8-1)
% Uzduoties formuleje pataisyti nesubalansuoti skliaustai.
f = @(x) (1 + 0.6*sin(2*pi*x/0.7) + 0.3*sin(2*pi*x))/2;
X = linspace(0, 1, 20);
Y = f(X);
[model1, loss1] = trainMLP(X, Y, 8, 100000, 0.03, 1e-5);
xTest = linspace(0, 1, 401);
yTest = f(xTest);
yPred = predictMLP(model1, xTest);
trainMSE1 = mean((predictMLP(model1, X) - Y).^2);
testMSE1 = mean((yPred - yTest).^2);

figure('Name', 'Funkcijos aproksimavimas', 'Color', 'w');
subplot(2,1,1);
plot(xTest, yTest, 'k-', 'LineWidth', 1.5); hold on;
plot(xTest, yPred, 'r--', 'LineWidth', 1.5);
plot(X, Y, 'bo', 'MarkerFaceColor', 'b'); grid on;
xlabel('x'); ylabel('y');
legend('Tikroji funkcija', 'MLP atsakas', '20 mokymo taškų', 'Location', 'best');
title(sprintf('Tinklas 1–8–1; patikros MSE = %.3g', testMSE1));
subplot(2,1,2);
semilogy(0:numel(loss1)-1, loss1, 'LineWidth', 1.3); grid on;
xlabel('Mokymo epocha'); ylabel('Mokymo MSE');
title('Mokymo paklaida');
exportgraphics(gcf, fullfile(outDir, 'funkcija.png'), 'Resolution', 160);

%% 2. Papildoma uzduotis: pavirsiaus aproksimavimas (2-8-1)
% Pavirsiaus formule uzduotyje nenurodyta, todel pasirenkame sia.
surfaceF = @(x1,x2) 0.5 + 0.25*sin(pi*x1) + 0.25*cos(pi*x2);
[a, b] = meshgrid(linspace(0, 1, 15));
X2 = [a(:)'; b(:)'];
Y2 = surfaceF(X2(1,:), X2(2,:));
[model2, loss2] = trainMLP(X2, Y2, 8, 100000, 0.03, 1e-5);
[aTest, bTest] = meshgrid(linspace(0, 1, 61));
zTrue = surfaceF(aTest, bTest);
zPred = reshape(predictMLP(model2, [aTest(:)'; bTest(:)']), size(aTest));
trainMSE2 = mean((predictMLP(model2, X2) - Y2).^2);
testMSE2 = mean((zPred(:) - zTrue(:)).^2);

figure('Name', 'Paviršiaus aproksimavimas', 'Color', 'w', ...
    'Position', [100 100 1100 750]);
subplot(2,2,1); surf(aTest, bTest, zTrue); shading interp;
title('Tikrasis paviršius'); xlabel('x_1'); ylabel('x_2'); zlabel('y');
subplot(2,2,2); surf(aTest, bTest, zPred); shading interp;
title('MLP paviršius'); xlabel('x_1'); ylabel('x_2'); zlabel('y');
subplot(2,2,3); surf(aTest, bTest, abs(zPred-zTrue)); shading interp;
title('Absoliuti paklaida'); xlabel('x_1'); ylabel('x_2'); zlabel('|e|');
subplot(2,2,4); semilogy(0:numel(loss2)-1, loss2, 'LineWidth', 1.3);
grid on; xlabel('Mokymo epocha'); ylabel('Mokymo MSE');
title(sprintf('Tinklas 2–8–1; patikros MSE = %.3g', testMSE2));
exportgraphics(gcf, fullfile(outDir, 'pavirsius.png'), 'Resolution', 160);

%% Ismokyti koeficientai ir rezultatai
disp('1-8-1 tinklo svoriai ir poslinkiai:'); disp(model1);
disp('2-8-1 tinklo svoriai ir poslinkiai:'); disp(model2);
fprintf('\nFunkcija: %d epochu, mokymo MSE %.8g, patikros MSE %.8g\n', ...
    numel(loss1)-1, trainMSE1, testMSE1);
fprintf('Pavirsius: %d epochu, mokymo MSE %.8g, patikros MSE %.8g\n', ...
    numel(loss2)-1, trainMSE2, testMSE2);
save(fullfile(outDir, 'koeficientai.mat'), 'model1', 'model2', ...
    'loss1', 'loss2', 'trainMSE1', 'testMSE1', 'trainMSE2', 'testMSE2');
assert(all(isfinite([loss1 loss2])), 'Mokymo paklaida nera baigtine.');
assert(testMSE1 < 1e-3 && testMSE2 < 1e-3, 'Per didele patikros paklaida.');

%% Vietines funkcijos
function [model, history] = trainMLP(X, Y, hiddenCount, maxEpochs, rate, targetMSE)
    % Stulpelis yra vienas pavyzdys; eilute yra vienas pozymis.
    % [0,1] -> [-1,1], kad tanh neuronai lengviau mokytusi.
    U = 2*X - 1;
    inputCount = size(X, 1);
    N = size(X, 2);
    model.W1 = randn(hiddenCount, inputCount)*sqrt(1/inputCount);
    model.b1 = zeros(hiddenCount, 1);
    model.W2 = randn(1, hiddenCount)*sqrt(1/hiddenCount);
    model.b2 = 0;
    vW1 = zeros(size(model.W1)); vb1 = zeros(size(model.b1));
    vW2 = zeros(size(model.W2)); vb2 = 0;
    momentum = 0.9;
    history = zeros(1, maxEpochs+1);
    for epoch = 0:maxEpochs
        % Tiesioginis sklidimas: tanh pasleptasis sluoksnis, tiesinis isejimas.
        H = tanh(model.W1*U + model.b1);
        Yhat = model.W2*H + model.b2;
        E = Yhat - Y;
        history(epoch+1) = mean(E.^2);
        if history(epoch+1) <= targetMSE || epoch == maxEpochs
            history = history(1:epoch+1);
            break;
        end
        % Atgalinis sklidimas: visi gradientai skaiciuojami iki atnaujinimo.
        D2 = 2*E/N;
        D1 = (model.W2'*D2).*(1-H.^2);
        gW2 = D2*H'; gb2 = sum(D2, 2);
        gW1 = D1*U'; gb1 = sum(D1, 2);
        % Gradientinis nusileidimas su inercija (momentum).
        vW1 = momentum*vW1 - rate*gW1;
        vb1 = momentum*vb1 - rate*gb1;
        vW2 = momentum*vW2 - rate*gW2;
        vb2 = momentum*vb2 - rate*gb2;
        model.W1 = model.W1 + vW1; model.b1 = model.b1 + vb1;
        model.W2 = model.W2 + vW2; model.b2 = model.b2 + vb2;
    end
end

function Yhat = predictMLP(model, X)
    % Prognozei naudojami tik ismokyti koeficientai, ne tiksline formule.
    H = tanh(model.W1*(2*X-1) + model.b1);
    Yhat = model.W2*H + model.b2;
end
