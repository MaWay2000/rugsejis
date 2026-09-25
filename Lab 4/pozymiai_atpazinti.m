function pozymiai = pozymiai_atpazinti(failas,~)
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
