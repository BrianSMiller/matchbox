function testPairwiseColumnIntegrity_Casey2019
% testPairwiseColumnIntegrity_Casey2019  Real-data check that pairwise's
% detect_observerK flags and <col>_observerK columns agree, for every
% column of every observer's own table -- not just t0/tEnd/fLow/fHigh.
%
% testMatchboxSmoke.m is synthetic and only carries t0/tEnd/fLow/fHigh/snr,
% so it never exercises what happens to an observer's OTHER columns
% (soundFolder, channel, classification, whatever real Raven/Koogu tables
% carry) on rows that observer didn't detect. Two mechanisms are
% responsible for making those "missing": localBlankify, for events opened
% by a later observer before this one existed, and outerjoin's own fill,
% for existing events this observer's join simply didn't match. A bug in
% either -- wrong "missing" sentinel for a column type, or a collapsed
% duplicate match leaving a winner row with blank data despite a true
% detect flag -- would show up as detect_observerK disagreeing with
% whether <col>_observerK is missing. This checks that agreement directly,
% on the real Casey2019 tables, so real column types get exercised.
%
% Not included in testMatchboxSmoke.m because it needs the real Casey2019
% files (S:\...), same as compareCaptureHistory_Casey2019.m and
% pairwiseOrderDependence_Casey2019.m.
%
% Run with: testPairwiseColumnIntegrity_Casey2019

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'), '-begin');

%% ---- load, same source as compareCaptureHistory_Casey2019 -------------
folder = 'S:\manuscripts\2023-PerceptionBias_effects_on_CallDensities\detections';
a1  = readtable(fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst1.csv'), ...
                'Delimiter', '\t', 'ReadVariableNames', true);
a2  = readtable(fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst2.csv'), ...
                'Delimiter', '\t', 'ReadVariableNames', true);
a3  = readtable(fullfile(folder, 'Casey2019_Bm-Ant-ABZ_snr_analyst3.csv'), ...
                'Delimiter', '\t', 'ReadVariableNames', true);
pgCsv  = fullfile(folder, 'subset_Casey2019_Ishmael_spectrogram_correlation_00320_events.csv');
dnnCsv = fullfile(folder, 'subset_Casey2019_Koogu_DNN_090_events.csv');
pg  = readtable(pgCsv);
dnn = readtable(dnnCsv, 'Delimiter', ',');

% Five observers: the worst case in the repo for exercising both new-event
% blankify (dnn/pg open plenty of events analysts 1-3 never sees) and
% duplicate-match collapse (analysts vs pg/dnn showed 13-1678 collapsed
% groups per observer in compareCaptureHistory_Casey2019).
tables = {a1, a2, a3, pg, dnn};
nObs   = numel(tables);
required = {'t0','tEnd','fLow','fHigh'};

ch = multiCaptureHistoryPairwise(tables{:}, 'verbose', false);

pass = true;
nChecked = 0;
nSkippedLogical = 0;

for k = 1:nObs
    dc = sprintf('detect_observer%d', k);
    extraCols = setdiff(tables{k}.Properties.VariableNames, required, 'stable');
    for c = 1:numel(extraCols)
        baseName = extraCols{c};

        if islogical(tables{k}.(baseName))
            % MATLAB's ismissing has no concept of a missing logical value
            % (islogical(NaN)==false), so it can never detect what
            % localBlankify does for logical columns (set to false). Not
            % checkable with this method; skip rather than report a false
            % failure.
            nSkippedLogical = nSkippedLogical + 1;
            continue;
        end

        col = sprintf('%s_observer%d', baseName, k);
        if ~ismember(col, ch.Properties.VariableNames)
            % Renamed or dropped by outerjoin's own collision handling
            % (e.g. a column name collides with 'key'); out of scope here.
            continue;
        end

        isMiss = ismissing(ch.(col));
        agree  = isequal(isMiss, ~ch.(dc));
        nChecked = nChecked + 1;
        pass = check(pass, agree, ...
            sprintf('observer %d: %s missingness matches detect flag', k, baseName));
    end
end

fprintf('\n%d column(s) checked across %d observers (%d logical column(s) skipped, not checkable)\n', ...
    nChecked, nObs, nSkippedLogical);
fprintf('testPairwiseColumnIntegrity_Casey2019: %s\n', ternary(pass, 'ALL PASS', 'FAILURES ABOVE'));
end

% -------------------------------------------------------------------------
function pass = check(pass, cond, name)
fprintf('  [%s] %s\n', ternary(cond, 'ok', 'XX'), name);
pass = pass && cond;
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
