%% compareCaptureHistory_Casey2019.m
% Functional comparison of the pairwise matcher (multiCaptureHistoryPairwise,
% matchbox method 'pairwise') against the clustered matcher (matchbox,
% method 'clustered') on the Common Ground Casey2019 ABZ dataset: three
% analysts (a1,a2,a3), Ishmael spectrogram correlation (pg), and Koogu DNN
% (dnn). We compare event counts, per-observer detection counts, observer-
% mask histograms, and duplicate-key structure.
%
% There is no ground truth here. This is a "does it run, and where does it
% differ" check, not a correctness proof. The pairwise path additionally
% needs doTimespansOverlap and timespanOverlap from the original detection
% toolbox.

%% ---- paths -----------------------------------------------------------
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'), '-begin');  % matchbox + matchers

%% ---- config ----------------------------------------------------------
siteCode       = 'Casey2019';
folder         = 'S:\manuscripts\2023-PerceptionBias_effects_on_CallDensities\detections';
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

%% ---- build pairwise and clustered -------------------------------------
obs   = {a1, a2, a3, pg, dnn};
nObs  = numel(obs);
label = 'analysts123+pg+dnn';

try
    pairwiseTab = multiCaptureHistoryPairwise(obs{:});
catch err
    warning('pairwise builder failed: %s', err.message);
    pairwiseTab = table();
end

clusteredTab = matchbox(obs{:}, 'method','clustered', ...
                'timeBuffer', timeBuffer, 'splitRule', splitRule);

writetable(clusteredTab, sprintf( ...
    'MultiObserverCaptureHistory_%s_%s_%s_clustered.csv', ...
    siteCode, classification, label));

%% ---- count comparison ------------------------------------------------
o = pairwiseTab; n = clusteredTab;
fprintf('\n%-22s %8s %8s %8s\n', 'Dataset', 'Pairwise', 'Clustered', 'Diff');
fprintf('%s\n', repmat('-', 1, 48));
ho = height(o); hn = height(n);
fprintf('%-22s %8g %8g %8g\n', label, ho, hn, hn-ho);
for i = 1:nObs
    col = sprintf('detect_observer%d', i);
    so = ternary(ismember(col, o.Properties.VariableNames), @() sum(o.(col)), NaN);
    sn = sum(n.(col));
    fprintf('  observer %-11g %8g %8g %8g\n', i, so, sn, sn-so);
end

%% ---- observer-mask histogram (pairwise vs clustered) ------------------
figure('units','centimeters','PaperPositionMode','auto','position',[10 10 24 18]);
tiledlayout(1, 2);
detCols = strcat("detect_", append("observer", string(1:nObs)));

nexttile
if all(ismember(detCols, o.Properties.VariableNames))
    histogram(categorical(cellstr(num2str(o{:,detCols}, '%g')))); grid on
end
title(sprintf('%s -- pairwise', label), 'Interpreter','none')
xlabel('Observer mask'); ylabel('Count')

nexttile
histogram(categorical(cellstr(num2str(n{:,detCols}, '%g')))); grid on
title(sprintf('%s -- clustered', label), 'Interpreter','none')
xlabel('Observer mask'); ylabel('Count')

%% ---- duplicate-key check ---------------------------------------------
% Both builders now guarantee one row per event (the pairwise builder's
% row-multiplication bug is fixed), so duplicate keys should be zero for
% both. Kept as a check, not just a demonstration.
fprintf('\nDuplicate-key structure\n%s\n', repmat('-', 1, 48));
for pair = {'pairwise', o; 'clustered', n}'
    lbl = pair{1}; tab = pair{2};
    if isempty(tab) || ~ismember('key', tab.Properties.VariableNames)
        fprintf('%-22s %-4s  (no key column)\n', label, lbl);
        continue
    end
    [~, ~, ic] = unique(tab.key);
    counts = accumarray(ic, 1);
    nDup   = sum(counts > 1);
    fprintf('%-22s %-4s  %d/%d events duplicated\n', label, lbl, nDup, numel(counts));
end

%% ---- local helper ----------------------------------------------------
function out = ternary(cond, fTrue, fFalse)
if cond, out = fTrue(); else, out = fFalse; end
end
