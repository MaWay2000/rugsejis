function rezultatai = ND1
% Mantas Matusevicius, DISfm-26. ND1: skaitmenu klasifikavimas.
% MATLAB adaptation of the existing scikit-learn example:
% https://scikit-learn.org/stable/auto_examples/classification/plot_digits_classification.html
baseDir = fileparts(mfilename('fullpath'));
outDir = fullfile(baseDir,'ND1_rezultatai');
if ~isfolder(outDir), mkdir(outDir); end
oldRng = rng; restoreRng = onCleanup(@() rng(oldRng));
rng(42,'twister');
dataFile = fullfile(baseDir,'digits.csv');
if ~isfile(dataFile)
    url = 'https://raw.githubusercontent.com/scikit-learn/scikit-learn/1.9.1/sklearn/datasets/data/digits.csv.gz';
    gzFile = websave(fullfile(baseDir,'digits.csv.gz'),url);
    gunzip(gzFile,baseDir);
end
raw = readmatrix(dataFile);
assert(isequal(size(raw),[1797 65]) && all(isfinite(raw),'all'));
X = raw(:,1:64); y = raw(:,65);
assert(all(ismember(y,0:9)));
XTrain = X(1:898,:); yTrain = y(1:898);
XTest = X(899:end,:); yTest = y(899:end);
% Nested, approximately balanced training subsets; fixed test set.
byClass = cell(10,1);
for digit = 0:9
    ids = find(yTrain == digit);
    byClass{digit+1} = ids(randperm(numel(ids)));
end
order = zeros(898,1); p = 0;
for j = 1:max(cellfun(@numel,byClass))
    for digit = 1:10
        if j <= numel(byClass{digit})
            p = p+1; order(p) = byClass{digit}(j);
        end
    end
end
assert(numel(unique(order)) == 898);
trainSizes = [100;300;600;898];
correct = zeros(4,1); errors = zeros(4,1); accuracy = zeros(4,1);
predictions = zeros(899,4); models = cell(4,1); trainingIndices = cell(4,1);
% exp(-distance^2/KernelScale^2): gamma=0.001 gives sqrt(1000).
svm = templateSVM('KernelFunction','gaussian','KernelScale',sqrt(1000), ...
    'BoxConstraint',1,'Standardize',false);
for k = 1:4
    if k == 4, ids = (1:898)'; else, ids = order(1:trainSizes(k)); end
    trainingIndices{k} = ids;
    models{k} = fitcecoc(XTrain(ids,:),yTrain(ids),'Learners',svm, ...
        'Coding','onevsone','ClassNames',(0:9)');
    predictions(:,k) = predict(models{k},XTest);
    correct(k) = sum(predictions(:,k) == yTest);
    errors(k) = 899-correct(k); accuracy(k) = 100*correct(k)/899;
    fprintf('Train=%d Test=899 Correct=%d Errors=%d Accuracy=%.6f%%\n', ...
        trainSizes(k),correct(k),errors(k),accuracy(k));
end
resultsTable = table(trainSizes,repmat(899,4,1),correct,errors,accuracy, ...
    'VariableNames',{'Train','Test','Correct','Errors','Accuracy_percent'});
disp(resultsTable);
cm = confusionmat(yTest,predictions(:,4),'Order',(0:9)');
f1 = figure('Name','ND1 - Confusion matrix','Color','w','Position',[80 80 740 620]);
confusionchart(cm,string(0:9));
title(sprintf('MATLAB SVM: %d/899 (%.2f%%)',correct(4),accuracy(4)));
exportgraphics(f1,fullfile(outDir,'klaidu_matrica.png'),'Resolution',180);
f2 = figure('Name','ND1 - Predictions','Color','w','Position',[100 100 960 440]);
tiledlayout(2,4,'TileSpacing','compact','Padding','compact');
good = find(predictions(:,4)==yTest,4);
bad = find(predictions(:,4)~=yTest,4);
exampleIds = [good;bad];
for k = 1:numel(exampleIds)
    i = exampleIds(k); nexttile;
    imagesc(reshape(XTest(i,:),8,8)',[0 16]); axis image off;
    title(sprintf('True: %d | Predicted: %d',yTest(i),predictions(i,4)));
end
colormap(f2,gray);
exportgraphics(f2,fullfile(outDir,'atpazinimo_pavyzdziai.png'),'Resolution',180);
f3 = figure('Name','ND1 - Training size','Color','w','Position',[120 120 820 420]);
plot(trainSizes,accuracy,'-o','LineWidth',2); grid on;
xlabel('Training images'); ylabel('Accuracy (%)'); ylim([0 100]);
title('Same 899 test images in all experiments');
for k = 1:4
    text(trainSizes(k),accuracy(k)-5,sprintf('%.2f%%',accuracy(k)), ...
        'HorizontalAlignment','center');
end
exportgraphics(f3,fullfile(outDir,'mokymo_kiekio_itaka.png'),'Resolution',180);
writetable(resultsTable,fullfile(outDir,'palyginimas.csv'));
rezultatai = struct('matlabVersion',version,'toolboxes',{ver}, ...
    'trainSizes',trainSizes,'testSize',899,'correct',correct,'errors',errors, ...
    'accuracy',accuracy,'confusionMatrix',cm,'seed',42);
fid = fopen(fullfile(outDir,'rezultatai.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(rezultatai)); fclose(fid);
save(fullfile(outDir,'modeliai_ir_prognozes.mat'),'models','predictions', ...
    'yTest','trainingIndices','resultsTable','rezultatai','exampleIds');
copyfile([mfilename('fullpath') '.m'],fullfile(outDir,'ND1.m'));
zip(fullfile(baseDir,'ND1_rezultatai.zip'),'ND1_rezultatai',baseDir);
fprintf('Results saved: %s\n',outDir);
end
