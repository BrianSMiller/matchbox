%% compareCaptureHistory_Casey2019.m
% Functional comparison of the old pairwise capture-history builder
% (multiCaptureHistory) against the new temporal-clustering builder
% (multiCaptureHistoryClustered) on the Common Ground Casey2019 ABZ dataset.
%
% Five observers: three analysts (a1,a2,a3), Ishmael spectrogram
% correlation (pg), and Koogu DNN (dnn). We build three combinations and
% compare event counts, per-observer detection counts, observer-mask
% histograms, and duplicate-key structure.
%
% There is no ground truth here. This is a "does it run, and where does it
% differ" check, not a correctness proof.

%% ---- config ----------------------------------------------------------
siteCode       = 'Casey2019';
folder         = 'detections';
classification = 'BmAntABZ';
timeBuffer     = 0;          % days. 0 = exact overlap. Try 5/86400 to test.
splitRule      = 'overlap';  % 'overlap' or 'snr'

ravenA2 = fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst2.csv');
ravenA1 = fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst1.csv');
ravenA3 = fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst3.csv');
pgCsv   = fullfile(folder, 'subset_Casey2019_Ishmael_spectrogram_correlation_00320_events.csv');
dnnCsv  = fullfile(folder, 'subset_Casey2019_Koogu_DNN_090_events.csv');

%% ---- load ------------------------------------------------------------
a2  = readtable(ravenA2, 'Delimiter', '\t', 'ReadVariableNames', true);
a1  = readtable(ravenA1, 'Delimiter', '\t', 'ReadVariableNames', true);
a3  = readtable(ravenA3, 'Delimiter', '\t', 'ReadVariableNames', true);
pg  = readtable(pgCsv);
dnn = readtable(dnnCsv,  'Delimiter', ',');

%% ---- ensure SNR on the spectrogram-correlation detections ------------
if ~any(strcmpi(pg.Properties.VariableNames, 'snr'))
    clear params
    params.showClips = false;
    params.noiseDelay = 1;
    params.freq       = [25 29];      % Blue whale Z

    pg = sortrows(pg, {'classification', 't0'});
    [~, rmsSignal, rmsNoise, noiseVar] = annotationSNR(pg, params);

    pg.signalRMSdB = 10*log10(rmsSignal(:));
    pg.noiseRMSdB  = 10*log10(rmsNoise(:));
    pg.noiseDev    = noiseVar(:);
    pg.snr         = pg.signalRMSdB - pg.noiseRMSdB;
    writetable(pg, [pgCsv(1:end-4) '_withSNR.csv']);
end

%% ---- build old and new for each combination --------------------------
combos = {
    'analysts123+pg',     {a1, a2, a3, pg}
    'analysts123+dnn',    {a1, a2, a3, dnn}
    'analysts123+pg+dnn', {a1, a2, a3, pg, dnn}
};
nCombo = size(combos, 1);

oldTabs = cell(nCombo, 1);
newTabs = cell(nCombo, 1);
nObs    = zeros(nCombo, 1);

for t = 1:nCombo
    obs      = combos{t, 2};
    nObs(t)  = numel(obs);

    try
        oldTabs{t} = multiCaptureHistory(obs{:});
    catch err
        warning('old builder failed on %s: %s', combos{t,1}, err.message);
        oldTabs{t} = table();
    end

    newTabs{t} = multiCaptureHistoryClustered(obs{:}, ...
                    'timeBuffer', timeBuffer, 'splitRule', splitRule);

    writetable(newTabs{t}, sprintf( ...
        'MultiObserverCaptureHistory_%s_%s_%s_clustered.csv', ...
        siteCode, classification, combos{t,1}));
end

%% ---- count comparison ------------------------------------------------
fprintf('\n%-22s %8s %8s %8s\n', 'Dataset', 'Old', 'New', 'Diff');
fprintf('%s\n', repmat('-', 1, 48));
for t = 1:nCombo
    o = oldTabs{t}; n = newTabs{t};
    ho = height(o); hn = height(n);
    fprintf('%-22s %8g %8g %8g\n', combos{t,1}, ho, hn, hn-ho);
    for i = 1:nObs(t)
        col = sprintf('detect_observer%d', i);
        so = ternary(ismember(col, o.Properties.VariableNames), @() sum(o.(col)), NaN);
        sn = sum(n.(col));
        fprintf('  observer %-11g %8g %8g %8g\n', i, so, sn, sn-so);
    end
end

%% ---- observer-mask histograms (old vs new) ---------------------------
figure('units','centimeters','PaperPositionMode','auto','position',[10 10 24 18]);
tiledlayout(nCombo, 2);
for t = 1:nCombo
    o = oldTabs{t}; n = newTabs{t};
    detCols = strcat("detect_", append("observer", string(1:nObs(t))));

    nexttile
    if all(ismember(detCols, o.Properties.VariableNames))
        histogram(categorical(cellstr(num2str(o{:,detCols}, '%g')))); grid on
    end
    title(sprintf('%s -- old', combos{t,1}), 'Interpreter','none')
    xlabel('Observer mask'); ylabel('Count')

    nexttile
    histogram(categorical(cellstr(num2str(n{:,detCols}, '%g')))); grid on
    title(sprintf('%s -- clustered', combos{t,1}), 'Interpreter','none')
    xlabel('Observer mask'); ylabel('Count')
end

%% ---- duplicate-key check ---------------------------------------------
% The clustered builder has one row per event, so duplicate keys must be
% zero. The old builder's duplicate keys are the lumping/splitting matches
% (and, historically, garbled-key artefacts).
fprintf('\nDuplicate-key structure\n%s\n', repmat('-', 1, 48));
for t = 1:nCombo
    for pair = {'old', oldTabs{t}; 'new', newTabs{t}}'
        label = pair{1}; tab = pair{2};
        if isempty(tab) || ~ismember('key', tab.Properties.VariableNames)
            fprintf('%-22s %-4s  (no key column)\n', combos{t,1}, label);
            continue
        end
        [~, ~, ic] = unique(tab.key);
        counts = accumarray(ic, 1);
        nDup   = sum(counts > 1);
        fprintf('%-22s %-4s  %d/%d events duplicated\n', ...
            combos{t,1}, label, nDup, numel(counts));
    end
end

%% ---- local helper ----------------------------------------------------
function out = ternary(cond, fTrue, fFalse)
if cond, out = fTrue(); else, out = fFalse; end
end
