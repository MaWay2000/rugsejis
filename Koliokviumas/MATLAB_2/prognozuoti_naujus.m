function prognozes = prognozuoti_naujus(modelioFailas, duomenuFailas, isvestiesFailas)
% Patikrina nauja CSV faila ir pateikia issaugoto modelio prognozes.

    if nargin < 3
        isvestiesFailas = "predictions_new.csv";
    end
    if ~isfile(modelioFailas)
        error("Modelio failas nerastas: %s", modelioFailas);
    end
    if ~isfile(duomenuFailas)
        error("Duomenu failas nerastas: %s", duomenuFailas);
    end

    ikeltas = load(modelioFailas, "paketas");
    if ~isfield(ikeltas, "paketas") || ~isfield(ikeltas.paketas, "schema")
        error("Modelio pakete nera paketo arba schemos.");
    end
    paketas = ikeltas.paketas;
    pozymiai = string(paketas.schema.pozymiai(:));
    laukiami = ["row_id"; pozymiai];

    failas = fopen(duomenuFailas, "r", "n", "UTF-8");
    if failas < 0
        error("Nepavyko atverti duomenu failo.");
    end
    valymas = onCleanup(@() fclose(failas));
    antraste = split(string(fgetl(failas)), ",");
    antraste = strip(antraste, '"');
    if numel(unique(antraste)) ~= numel(antraste)
        error("CSV antrasteje yra pasikartojanciu stulpeliu pavadinimu.");
    end
    clear valymas;

    lentele = readtable(duomenuFailas, "VariableNamingRule", "preserve", ...
        "TextType", "string");
    vardai = string(lentele.Properties.VariableNames(:));
    truksta = setdiff(laukiami, vardai, "stable");
    papildomi = setdiff(vardai, laukiami, "stable");
    if ~isempty(truksta)
        error("Truksta stulpeliu: %s", join(truksta, ", "));
    end
    if ~isempty(papildomi)
        error("Yra papildomu stulpeliu: %s", join(papildomi, ", "));
    end

    rowId = lentele.("row_id");
    if ~isnumeric(rowId) || any(~isfinite(rowId)) || numel(unique(rowId)) ~= numel(rowId)
        error("row_id turi buti unikalus baigtinis skaitinis stulpelis.");
    end

    X = zeros(height(lentele), numel(pozymiai));
    for j = 1:numel(pozymiai)
        stulpelis = lentele.(pozymiai(j));
        if ~isnumeric(stulpelis)
            error("Stulpelis %s nera skaitinis.", pozymiai(j));
        end
        if any(isinf(stulpelis))
            error("Stulpelyje %s yra begaliniu reiksmiu.", pozymiai(j));
        end
        X(:, j) = stulpelis;
    end

    balai = prognozuotiIsPaketo(paketas, X);
    if paketas.sprendimoBud == "majority"
        klases = repmat(paketas.dazniausiaKlase, size(balai));
    elseif paketas.sprendimoBud == "always_zero"
        klases = zeros(size(balai));
    else
        klases = double(balai >= paketas.slenkstis);
    end

    prognozes = table(rowId, klases, balai, ...
        repmat(paketas.slenkstis, size(balai)), ...
        repmat(string(paketas.versija), size(balai)), ...
        'VariableNames', {'row_id', 'class', 'score', 'threshold', 'model_version'});
    writetable(prognozes, isvestiesFailas);
end

function balai = prognozuotiIsPaketo(paketas, X)
    if paketas.tipas == "majority"
        balai = repmat(paketas.brukaloDalis, size(X, 1), 1);
        return;
    end
    for j = 1:size(X, 2)
        truksta = isnan(X(:, j));
        X(truksta, j) = paketas.paruosimas.medianos(j);
    end
    X = X(:, paketas.pozymiuKauke);
    if paketas.paruosimas.standartizuoti
        X = (X - paketas.paruosimas.vidurkiai) ./ paketas.paruosimas.nuokrypiai;
    end
    [~, visiBalai] = predict(paketas.modelis, X);
    if paketas.tipas == "rf" || paketas.tipas == "hcvr_rf"
        klases = str2double(string(paketas.modelis.ClassNames));
    else
        klases = paketas.modelis.ClassNames;
    end
    stulpelis = find(klases == 1, 1);
    if isempty(stulpelis)
        error("Modelio isvestyje nerasta klases 1 balo.");
    end
    balai = visiBalai(:, stulpelis);
end
