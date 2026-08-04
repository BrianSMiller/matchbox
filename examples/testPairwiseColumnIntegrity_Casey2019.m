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
% whether <col>_observerK is missing.
%
% Only ONE direction of that agreement is a genuine invariant: not
% detected implies missing. The reverse -- detected implies not missing --
% only holds if the column is fully populated in the observer's OWN
% source table. Some detector output carries optional, sometimes-blank
% metadata fields even for genuine detections (a Koogu run surfaced
% SequenceBitmap/detectionType/bearingAmbiguity as already-sparse in the
% raw table -- PAMGuard-style bearing/sequence fields a DNN detector
% doesn't populate). Asserting the reverse direction there would be
% checking the wrong thing: real source sparsity, not a matchbox bug. So
% each column is checked against the stronger bidirectional invariant only
% if its source table has no missing values of its own; otherwise only the
% one-directional invariant is checked, and that narrower scope is
% reported alongside the result rather than silently assumed.
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

% Same five-observer combination as compareCaptureHistory_Casey2019.m and
% pairwiseOrderDependence_Casey2019.m.
tables = {a1, a2, a3, pg, dnn};
nObs   = numel(tables);
required = {'t0','tEnd','fLow','fHigh'};

ch = multiCaptureHistoryPairwise(tables{:}, 'verbose', false);

pass = true;
nChecked = 0;
nSkippedLogical = 0;
nSourceSparse = 0;

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

        isMiss   = ismissing(ch.(col));
        detected = ch.(dc);
        notDetectedAreMissing = all(isMiss(~detected));
        nChecked = nChecked + 1;

        if any(ismissing(tables{k}.(baseName)))
            % Source column already carries genuine missing values (an
            % optional detector field), so a detected row is still
            % allowed to be missing. Only the one-directional invariant
            % is meaningful here.
            nSourceSparse = nSourceSparse + 1;
            pass = check(pass, notDetectedAreMissing, ...
                sprintf('observer %d: %s (source has missing values; not-detected->missing only)', k, baseName));
        else
            detectedAreNotMissing = all(~isMiss(detected));
            agree = notDetectedAreMissing && detectedAreNotMissing;
            pass = check(pass, agree, ...
                sprintf('observer %d: %s missingness matches detect flag', k, baseName));
        end
    end
end

fprintf(['\n%d column(s) checked across %d observers (%d logical column(s) skipped, ' ...
         'not checkable; %d checked one-directionally, source already sparse)\n'], ...
    nChecked, nObs, nSkippedLogical, nSourceSparse);
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
