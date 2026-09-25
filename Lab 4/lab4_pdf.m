%% 4 laboratorinis darbas. Skaitmenu atpazinimas vaizde
% Mantas Matusevicius, DISfm-26
clear; clc; close all;

%% 1. Duomenys
mokymo_failas = 'mokymas.jpg';
testo_failas = 'testas.jpg';
eiluciu_sk = 4;

% Mokymo lape kiekvienoje eiluteje yra skaiciai nuo 1 iki 7.
mokymo_atsakymai = repmat(1:7,1,eiluciu_sk);

% Tikrieji testavimo lapo skaiciai.
testo_atsakymai = [3 2 1 7 1 2 3, 3 3 4 5 6 7 1, ...
    7 6 5 4 3 2 1, 6 5 3 1 2 4 3];

%% 2. Mokymo ir testavimo lapu pozymiai
mokymo_pozymiai = pozymiai_atpazinti(mokymo_failas,eiluciu_sk);
testo_pozymiai = pozymiai_atpazinti(testo_failas,eiluciu_sk);
P = mokymo_pozymiai;
Ptest = testo_pozymiai;

if size(P,2) ~= length(mokymo_atsakymai)
    error('Mokymo lape turi buti 28 skaitmenys.');
end
if size(Ptest,2) ~= length(testo_atsakymai)
    error('Testavimo lape turi buti 28 skaitmenys.');
end

% Pageidaujami tinklo atsakymai skaiciams 1-7.
T = repmat(eye(7),1,eiluciu_sk);

%% 3. RBF tinklu mokymas
rbf13 = newrb(P,T,0,1,13,100);
rbf7 = newrb(P,T,0,1,7,100);

%% 4. Testavimo skaitmenu atpazinimas
Y13 = sim(rbf13,Ptest);
Y7 = sim(rbf7,Ptest);
[~,ats13] = max(Y13);
[~,ats7] = max(Y7);

%% 5. Rezultatai
teisingi13 = sum(ats13 == testo_atsakymai);
teisingi7 = sum(ats7 == testo_atsakymai);
disp(['RBF 13: ' num2str(teisingi13) ' is 28 teisingai']);
disp(['RBF 7: ' num2str(teisingi7) ' is 28 teisingai']);

rezultatai = table((1:28)',testo_atsakymai',ats13',ats7', ...
    'VariableNames',{'Nr','Tikras','RBF13','RBF7'});
disp(rezultatai);

%% 6. Spalvota lentele
langas = uifigure('Name','Skaitmenu atpazinimo rezultatai', ...
    'Position',[100 40 520 780]);
lentele = uitable(langas,'Data',rezultatai, ...
    'Position',[20 20 480 740],'RowName',[]);

zalia = uistyle('BackgroundColor',[0.72 0.91 0.72]);
raudona = uistyle('BackgroundColor',[1 0.72 0.72]);
prognozes = [ats13;ats7];

for k = 1:2
    geri = find(prognozes(k,:) == testo_atsakymai);
    blogi = find(prognozes(k,:) ~= testo_atsakymai);
    addStyle(lentele,zalia,'cell', ...
        [geri' repmat(k+2,length(geri),1)]);
    addStyle(lentele,raudona,'cell', ...
        [blogi' repmat(k+2,length(blogi),1)]);
end
