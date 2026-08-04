function testScoreDetectionsSmoke
% testScoreDetectionsSmoke  Fast invariant checks for scoreDetections and
% scoreDetectionsSweep. No external data.
%
% Run with: testScoreDetectionsSmoke

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));

pass = true;
day  = 1/86400;
mk = @(t0,tEnd) table(t0(:), tEnd(:), 26*ones(numel(t0),1), 28*ones(numel(t0),1), ...
                      'VariableNames', {'t0','tEnd','fLow','fHigh'});

%% ---- scoreDetections: known confusion matrix ---------------------------
% 5 ground-truth calls; detector gets 3 right, misses 2, and has 1 false
% alarm: TP=3, FP=1, FN=2, numGroundTrue=5.
gt  = mk([10 50 100 150 200]*day, [12 52 102 152 202]*day);
det = mk([10 50 100 300]*day,     [12 52 102 302]*day);

ch = matchbox(gt, det, 'method','clustered', 'timeBuffer', 3*day, 'verbose', false);

r = scoreDetections(ch, 1, 2);
pass = check(pass, r.truePositive == 3 && r.falsePositive == 1 && ...
                    r.falseNegative == 2 && r.numGroundTrue == 5, ...
             'scoreDetections confusion matrix counts');
pass = check(pass, abs(r.precision - 3/4) < 1e-12 && abs(r.recall - 3/5) < 1e-12, ...
             'scoreDetections precision/recall values');

% Named-observer selection gives the same answer as indexed selection.
rNamed = scoreDetections(ch, 'observer1', 'observer2');
pass = check(pass, isequal(r, rNamed), 'scoreDetections named observer selection matches indexed');

% numAbsent: present only when supplied, and computed correctly when it is.
pass = check(pass, ~ismember('trueNegative', r.Properties.VariableNames) && ...
                    ~ismember('falseAlarmRate', r.Properties.VariableNames), ...
             'scoreDetections omits trueNegative/falseAlarmRate without numAbsent');
rAbs = scoreDetections(ch, 1, 2, 'numAbsent', 100);
pass = check(pass, rAbs.trueNegative == 99 && abs(rAbs.falseAlarmRate - 0.01) < 1e-12, ...
             'scoreDetections trueNegative/falseAlarmRate with numAbsent');

% Ground truth is a genuine choice, not hardcoded: swapping which side is
% "truth" gives a different, but internally consistent, answer.
rSwap = scoreDetections(ch, 2, 1);
pass = check(pass, rSwap.numGroundTrue == 4 && rSwap.truePositive == 3, ...
             'scoreDetections ground truth is caller-chosen, not fixed to observer1');

% Unknown observer errors with a useful message, doesn't silently return
% garbage.
pass = check(pass, threws(@() scoreDetections(ch, 5, 2)), ...
             'scoreDetections errors on unknown observer index');

% Duplicate keys are asserted against, not silently corrected for (that
% correction belonged to the pre-2026 legacy pairwise builder's row-
% multiplication bug, which no longer exists -- see
% multiCaptureHistoryPairwise.m).
chDup = ch([1 1 2:end], :);   % manually break the one-row-per-event contract
pass = check(pass, threws(@() scoreDetections(chDup, 1, 2)), ...
             'scoreDetections asserts against duplicate keys');

%% ---- scoreDetectionsSweep: table + scoreCol -----------------------------
% 3 ground-truth calls; 4 candidate detections at varying scores, one of
% which (t=300) is a false alarm at every threshold that keeps it.
gt2  = mk([10 50 100]*day, [12 52 102]*day);
cand = mk([10 50 100 300]*day, [12 52 102 302]*day);
cand.score = [0.9; 0.6; 0.4; 0.95];

thresholds = [0.3 0.5 0.7 0.95 2.0];   % 2.0 keeps nothing -> should be dropped
matchOpts  = {'method','clustered', 'timeBuffer', 3*day, 'verbose', false};

pr = scoreDetectionsSweep(gt2, cand, thresholds, 'scoreCol','score', 'matchOpts', matchOpts);

pass = check(pass, height(pr) == 4 && ~ismember(2.0, pr.threshold), ...
             'scoreDetectionsSweep drops thresholds with no candidates');
pass = check(pass, issorted(pr.threshold), 'scoreDetectionsSweep output sorted by threshold');

expected = containers.Map({0.3, 0.5, 0.7, 0.95}, ...
    {[3 1], [2 1], [1 1], [0 1]});   % [truePositive, falsePositive] per threshold
okRows = true;
for i = 1:height(pr)
    e = expected(pr.threshold(i));
    okRows = okRows && pr.truePositive(i) == e(1) && pr.falsePositive(i) == e(2);
end
pass = check(pass, okRows, 'scoreDetectionsSweep per-threshold counts match hand-computed values');

pass = check(pass, threws(@() scoreDetectionsSweep(gt2, cand, thresholds, 'matchOpts', matchOpts)), ...
             'scoreDetectionsSweep requires scoreCol for a table input');
pass = check(pass, threws(@() scoreDetectionsSweep(gt2, cand, thresholds, 'scoreCol','nope', 'matchOpts', matchOpts)), ...
             'scoreDetectionsSweep errors on unknown scoreCol');

%% ---- scoreDetectionsSweep: cell array, one table per threshold ---------
threshCell = [0.3 0.5 0.7 0.95];
candByThresh = arrayfun(@(t) cand(cand.score >= t, :), threshCell, 'UniformOutput', false);

prCell = scoreDetectionsSweep(gt2, candByThresh, threshCell, 'matchOpts', matchOpts);
pass = check(pass, height(prCell) == 4, 'scoreDetectionsSweep (cell array) row count');
pass = check(pass, isequal(prCell.precision, pr.precision), ...
             'scoreDetectionsSweep cell-array path matches scoreCol path on the same data');

pass = check(pass, threws(@() scoreDetectionsSweep(gt2, candByThresh, [0.3 0.5], 'matchOpts', matchOpts)), ...
             'scoreDetectionsSweep errors when cell array size does not match thresholds');

% Cell array + scoreCol together is not an error, just ignored -- confirm
% the warning fires so a mismatched call doesn't go unnoticed.
warning('off', 'all'); lastwarn('');
scoreDetectionsSweep(gt2, candByThresh, threshCell, 'scoreCol','score', 'matchOpts', matchOpts);
[~, warnId] = lastwarn();
warning('on', 'all');
pass = check(pass, strcmp(warnId, 'scoreDetectionsSweep:scoreColIgnored'), ...
             'scoreDetectionsSweep warns when scoreCol is given with a cell array');

% No threshold produces any candidates: returns an empty table, not an
% error.
prEmpty = scoreDetectionsSweep(gt2, cand, [5 6], 'scoreCol','score', 'matchOpts', matchOpts);
pass = check(pass, isempty(prEmpty), 'scoreDetectionsSweep returns empty table, not an error, when nothing crosses threshold');

fprintf('\ntestScoreDetectionsSmoke: %s\n', ternary(pass, 'ALL PASS', 'FAILURES ABOVE'));
end

% -------------------------------------------------------------------------
function tf = threws(fn)
tf = false;
try, fn(); catch, tf = true; end
end

function pass = check(pass, cond, name)
fprintf('  [%s] %s\n', ternary(cond, 'ok', 'XX'), name);
pass = pass && cond;
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
