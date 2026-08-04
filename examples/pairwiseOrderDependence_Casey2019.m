%% pairwiseOrderDependence_Casey2019.m
% How big is pairwise's order dependence on real data? gallery.m Example 3
% shows it's real, on a hand-built scenario tuned to make the mechanism
% visible. compareCaptureHistory_Casey2019.m shows pairwise runs clean
% (zero duplicate keys) on the Common Ground Casey2019 ABZ dataset. Neither
% says how much the full five-observer combination actually moves under
% reversed observer order. This does: same dataset, forward and reversed,
% pairwise only, event counts and per-observer detection counts.
%
% Not a pass/fail check -- there is no "correct" order to compare against.
% This is a magnitude read, deliberately quieter than
% compareCaptureHistory_Casey2019.m (no clustered comparison, no figures,
% no duplicate-key check -- that's already covered there).

%% ---- paths -------------------------------------------------------------
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'), '-begin');  % matchbox + matchers

%% ---- config --------------------------------------------------------------
folder     = 'S:\manuscripts\2023-PerceptionBias_effects_on_CallDensities\detections';
timeBuffer = 0;  % days. 0 = exact overlap, matching compareCaptureHistory_Casey2019.

ravenA1 = fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst1.csv');
ravenA2 = fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst2.csv');
ravenA3 = fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst3.csv');
pgCsv   = fullfile(folder, 'subset_Casey2019_Ishmael_spectrogram_correlation_00320_events.csv');
dnnCsv  = fullfile(folder, 'subset_Casey2019_Koogu_DNN_090_events.csv');

%% ---- load ----------------------------------------------------------------
a1  = readtable(ravenA1, 'Delimiter', '\t', 'ReadVariableNames', true);
a2  = readtable(ravenA2, 'Delimiter', '\t', 'ReadVariableNames', true);
a3  = readtable(ravenA3, 'Delimiter', '\t', 'ReadVariableNames', true);
pg  = readtable(pgCsv);
dnn = readtable(dnnCsv, 'Delimiter', ',');

%% ---- forward vs reversed, pairwise only -----------------------------------
obs   = {a1, a2, a3, pg, dnn};
nObs  = numel(obs);
ord   = fliplr(1:nObs);
label = 'analysts123+pg+dnn';

fwd = multiCaptureHistoryPairwise(obs{:},   'timeBuffer', timeBuffer, 'verbose', false);
rev = multiCaptureHistoryPairwise(obs{ord}, 'timeBuffer', timeBuffer, 'verbose', false);

fprintf('\n%-22s %8s %8s %8s\n', 'Dataset', 'Fwd', 'Rev', 'Diff');
fprintf('%s\n', repmat('-', 1, 48));
hf = height(fwd); hr = height(rev);
fprintf('%-22s %8g %8g %8g\n', label, hf, hr, hr-hf);

% Physical observer i sits at slot i in fwd, but at slot (nObs-i+1) in
% rev (ord reverses the input order), so compare detect_observer columns
% across the corresponding slots, not the same column name.
for i = 1:nObs
    colFwd = sprintf('detect_observer%d', i);
    colRev = sprintf('detect_observer%d', nObs - i + 1);
    sf = sum(fwd.(colFwd));
    sr = sum(rev.(colRev));
    fprintf('  observer %-11g %8g %8g %8g\n', i, sf, sr, sr-sf);
end
