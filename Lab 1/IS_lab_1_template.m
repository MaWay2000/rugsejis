%Classification using perceptron

%Reading apple images
A1=imread('apple_04.jpg');
A2=imread('apple_05.jpg');
A3=imread('apple_06.jpg');
A4=imread('apple_07.jpg');
A5=imread('apple_11.jpg');
A6=imread('apple_12.jpg');
A7=imread('apple_13.jpg');
A8=imread('apple_17.jpg');
A9=imread('apple_19.jpg');

%Reading pears images
P1=imread('pear_01.jpg');
P2=imread('pear_02.jpg');
P3=imread('pear_03.jpg');
P4=imread('pear_09.jpg');

%Calculate for each image, colour and roundness
%For Apples
%1st apple image(A1)
hsv_value_A1=spalva_color(A1); %color
metric_A1=apvalumas_roundness(A1); %roundness
%2nd apple image(A2)
hsv_value_A2=spalva_color(A2); %color
metric_A2=apvalumas_roundness(A2); %roundness
%3rd apple image(A3)
hsv_value_A3=spalva_color(A3); %color
metric_A3=apvalumas_roundness(A3); %roundness
%4th apple image(A4)
hsv_value_A4=spalva_color(A4); %color
metric_A4=apvalumas_roundness(A4); %roundness
%5th apple image(A5)
hsv_value_A5=spalva_color(A5); %color
metric_A5=apvalumas_roundness(A5); %roundness
%6th apple image(A6)
hsv_value_A6=spalva_color(A6); %color
metric_A6=apvalumas_roundness(A6); %roundness
%7th apple image(A7)
hsv_value_A7=spalva_color(A7); %color
metric_A7=apvalumas_roundness(A7); %roundness
%8th apple image(A8)
hsv_value_A8=spalva_color(A8); %color
metric_A8=apvalumas_roundness(A8); %roundness
%9th apple image(A9)
hsv_value_A9=spalva_color(A9); %color
metric_A9=apvalumas_roundness(A9); %roundness

%For Pears
%1st pear image(P1)
hsv_value_P1=spalva_color(P1); %color
metric_P1=apvalumas_roundness(P1); %roundness
%2nd pear image(P2)
hsv_value_P2=spalva_color(P2); %color
metric_P2=apvalumas_roundness(P2); %roundness
%3rd pear image(P3)
hsv_value_P3=spalva_color(P3); %color
metric_P3=apvalumas_roundness(P3); %roundness
%2nd pear image(P4)
hsv_value_P4=spalva_color(P4); %color
metric_P4=apvalumas_roundness(P4); %roundness

%selecting features(color, roundness, 3 apples and 2 pears)
%A1,A2,A3,P1,P2
%building matrix 2x5
x1=[hsv_value_A1 hsv_value_A2 hsv_value_A3 hsv_value_P1 hsv_value_P2];
x2=[metric_A1 metric_A2 metric_A3 metric_P1 metric_P2];
% estimated features are stored in matrix P:
P=[x1;x2];

%Desired output vector
T=[1;1;1;-1;-1];

%% train single perceptron with two inputs and one output

% generate random initial values of w1, w2 and b
w1 = randn(1);
w2 = randn(1);
b = randn(1);

% calculate wieghted sum with randomly generated parameters
%v1 = <...>; % write your code here
% calculate current output of the perceptron 
if x1(1)*w1 + x2(1)*w2 + b > 0
	y = 1;
else
    y = -1;
end

% calculate the error
e1 = T(1) - y;

% repeat the same for the rest 4 inputs x1 and x2
% calculate wieghted sum with randomly generated parameters
% v2 = <...> ; % write your code here
% calculate current output of the perceptron

% Antras vaisius
v2 = x1(2)*w1 + x2(2)*w2 + b;
if v2 > 0
    y = 1;
else
    y = -1;
end
e2 = T(2) - y;

% Trecias vaisius
v3 = x1(3)*w1 + x2(3)*w2 + b;
if v3 > 0
    y = 1;
else
    y = -1;
end
e3 = T(3) - y;

% Ketvirtas vaisius
v4 = x1(4)*w1 + x2(4)*w2 + b;
if v4 > 0
    y = 1;
else
    y = -1;
end
e4 = T(4) - y;

% Penktas vaisius
v5 = x1(5)*w1 + x2(5)*w2 + b;
if v5 > 0
    y = 1;
else
    y = -1;
end
e5 = T(5) - y;

% ar yra klaidu ? 0 = ne
e = abs(e1) + abs(e2) + abs(e3) + abs(e4) + abs(e5);


% Mokymo algoritmas
eta = 0.03;
ciklas = 0;

% LENTELEI: kiekvienoje eiluteje saugome viena mokymo zingsni
istorija = zeros(0, 15);
zingsnis = 0;

while e ~= 0
    ciklas = ciklas + 1;
    n = 1;
    % Mokome su kiekvienu vaisiumi
    while n <= 5
        % LENTELEI: svoriai pries sio vaisiaus mokyma
        w1_pries = w1;
        w2_pries = w2;
        b_pries = b;

        v = x1(n)*w1 + x2(n)*w2 + b;
        if v > 0
            y = 1;
        else
            y = -1;
        end

        % Momentine klaida ir parametru atnaujinimas
        klaida = T(n) - y;
        w1 = w1 + eta*klaida*x1(n);
        w2 = w2 + eta*klaida*x2(n);
        b = b + eta*klaida;

        % LENTELEI: prognoze, klaida ir svoriai pries bei po
        zingsnis = zingsnis + 1;
        istorija(zingsnis,:) = [ciklas, n, x1(n), x2(n), ...
            T(n), v, y, klaida, w1_pries, w2_pries, b_pries, ...
            w1, w2, b, NaN];
        n = n + 1;
    end

    % Tikriname visus vaisius nekeisdami svoriu
    e = 0;
    n = 1;
    while n <= 5
        v = x1(n)*w1 + x2(n)*w2 + b;
        if v > 0
            y = 1;
        else
            y = -1;
        end
        e = e + abs(T(n) - y);
        n = n + 1;
    end

    % LENTELEI: 15 stulpelyje - klaidu suma po viso ciklo
    istorija(zingsnis-4:zingsnis, 15) = e;
end

% LENTELES RODYMAS: vaisiai 1-5 yra A1, A2, A3, P1, P2
mokymo_lentele = array2table(istorija, 'VariableNames', ...
    {'ciklas', 'Vaisius', 'Spalva', 'Apvalumas', 'T', 'Suma', ...
    'y', 'Klaida', 'w1_pries', 'w2_pries', 'b_pries', ...
    'w1_po', 'w2_po', 'b_po', 'klaidu'});
mokymo_lentele = movevars(mokymo_lentele, 'Suma', 'Before', 'T');
mokymo_lentele = movevars(mokymo_lentele, 'w1_po', 'After', 'w1_pries');
mokymo_lentele = movevars(mokymo_lentele, 'w2_po', 'After', 'w2_pries');
% Rodome tik lenteles duomenis, be tusciu papildomu stulpeliu
lenteles_langas = uifigure('Name', 'Mokymo lentele', ...
    'Position', [1033 347 828 650]);
lenteles_isdestymas = uigridlayout(lenteles_langas, [1 1]);
uitable(lenteles_isdestymas, 'Data', mokymo_lentele, ...
    'ColumnName', mokymo_lentele.Properties.VariableNames, ...
        'ColumnEditable', false, 'ColumnWidth', {47, 54, 51, 82, 50, 20, 22, 49, 65, 63, 66, 52, 56, 53, 51});

% Galutinis rezultatas
disp(['ciklas = ', num2str(ciklas), ', klaidos = ', num2str(e)]);
if e == 0
    disp('Visi vaisiai atpazinti teisingai.');
end

% LENTELES SPALVOS: raudona - klaida, zalia - teisinga prognoze arba
% pakeistas svoris
lenteles_vaizdas = findobj(lenteles_langas, 'Type', 'uitable');
raudona = uistyle('BackgroundColor', [1 0.82 0.82]);
zalia = uistyle('BackgroundColor', [0.80 0.94 0.82]);
pakeistas = uistyle('BackgroundColor', [0.80 0.94 0.82], 'FontWeight', 'bold');
removeStyle(lenteles_vaizdas);
eilute = 1;
while eilute <= height(mokymo_lentele)
    if mokymo_lentele.Klaida(eilute) ~= 0
        addStyle(lenteles_vaizdas, raudona, 'cell', [eilute 7; eilute 8]);
    else
        addStyle(lenteles_vaizdas, zalia, 'cell', [eilute 7; eilute 8]);
    end
    stulpelis = 9;
    while stulpelis <= 13
        if mokymo_lentele{eilute, stulpelis} ~= mokymo_lentele{eilute, stulpelis+1}
            addStyle(lenteles_vaizdas, pakeistas, 'cell', [eilute stulpelis+1]);
        end
        stulpelis = stulpelis + 2;
    end
    eilute = eilute + 1;
end

% GRAFIKAI: perceptrono mokymas
if ~isempty(istorija)
    mokymo_langas = uifigure('Name', 'Perceptrono mokymas', ...
        'Position', [1391 204 650 812]);
    mokymo_tinklelis = uigridlayout(mokymo_langas, [3 1]);
    % Issaugoti grafiku dydziai: du virsutiniai ir aukstesnis apatinis.
    mokymo_tinklelis.RowHeight = {'1x', '1x', '1.2x'};
    klaidu_asys = uiaxes(mokymo_tinklelis);
    ciklu_eilutes = 5:5:size(istorija, 1);
    plot(klaidu_asys, istorija(ciklu_eilutes, 1), ...
        istorija(ciklu_eilutes, 15), '-o', 'LineWidth', 1.5);
    hold(klaidu_asys, 'on');
    yline(klaidu_asys, 0, '--', 'Nulis klaidu');
    plot(klaidu_asys, istorija(end, 1), istorija(end, 15), ...
        'ro', 'MarkerFaceColor', 'r');
    hold(klaidu_asys, 'off');
    grid(klaidu_asys, 'on');
    xlabel(klaidu_asys, 'Ciklas');
    ylabel(klaidu_asys, 'Klaidu suma');
    title(klaidu_asys, 'Klaidu suma patikrinus visus 5 vaisius');
    svoriu_asys = uiaxes(mokymo_tinklelis);
    svoriu_eiga = [istorija(1, 9:11); istorija(:, 12:14)];
    plot(svoriu_asys, 0:size(istorija, 1), svoriu_eiga, 'LineWidth', 1.2);
    grid(svoriu_asys, 'on');
    xlabel(svoriu_asys, 'Mokymo zingsnis (vienas vaisius)');
    ylabel(svoriu_asys, 'Parametro reiksme');
    title(svoriu_asys, 'Svoriu ir poslinkio kitimas');
    legend(svoriu_asys, 'w1', 'w2', 'b', 'Location', 'best');
    bendros_asys = uiaxes(mokymo_tinklelis);
    hold(bendros_asys, 'on');
    svoriu_spalvos = [0 0.4470 0.7410; 0.8500 0.3250 0.0980; 0.9290 0.6940 0.1250];
    liniju_stiliai = {'-', '--', ':', '-.', '-'};
    vaisius = 1;
    while vaisius <= 5
        vaisiaus_eilutes = istorija(:, 2) == vaisius;
        svoris = 1;
        while svoris <= 3
            plot(bendros_asys, istorija(vaisiaus_eilutes, 1), ...
                istorija(vaisiaus_eilutes, 11+svoris), ...
                'Color', svoriu_spalvos(svoris,:), ...
                'LineStyle', liniju_stiliai{vaisius}, 'LineWidth', 1.2);
            svoris = svoris + 1;
        end
        vaisius = vaisius + 1;
    end
    hold(bendros_asys, 'off');
    grid(bendros_asys, 'on');
    xlabel(bendros_asys, 'Ciklas');
    ylabel(bendros_asys, 'Parametro reiksme');
    title(bendros_asys, 'Visi 5 vaisiai kartu');
    legend(bendros_asys, 'w1', 'w2', 'b', 'Location', 'best');
end
