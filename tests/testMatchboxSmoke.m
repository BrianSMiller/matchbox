function testMatchboxSmoke
% testMatchboxSmoke  Fast invariant checks for multiCaptureHistoryClustered.
%   No external data. Confirms the core guarantees hold on a tiny fixture:
%   one row per event, unique keys, correct detect flags, and independence
%   from observer input order. Run with: testMatchboxSmoke
%
% For the full illustrated validation ladder see
% examples/testCaptureHistoryGallery.m.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));   % put the matcher on the path

pass = true;

% Fixture: 3 calls at t = 10, 100, 200 s (in days). Observer 1 sees all
% three; observer 2 sees calls 1 and 3; observer 2 also splits call 3 into
% two boxes.
mk = @(t0,tEnd) table(t0(:), tEnd(:), 26*ones(numel(t0),1), 28*ones(numel(t0),1), ...
                      'VariableNames', {'t0','tEnd','fLow','fHigh'});
day = 1/86400;
d1 = mk([10 100 200]*day,        [22 112 212]*day);
d2 = mk([11 201 209]*day,        [23 205 214]*day);   % misses call 2, splits call 3

ch = multiCaptureHistoryClustered(d1, d2, 'timeBuffer', 3*day, ...
                                  'splitRule', 'overlap', 'verbose', false);

% 1. one row per event, unique keys
pass = check(pass, height(ch) == numel(unique(ch.key)), 'unique keys');

% 2. three events recovered
pass = check(pass, height(ch) == 3, 'three events');

% 3. detect flags: obs1 on all three, obs2 on calls 1 and 3 only
[~, ord] = sort(ch.t0);
d1flag = ch.detect_observer1(ord);
d2flag = ch.detect_observer2(ord);
pass = check(pass, all(d1flag) && isequal(d2flag(:)', logical([1 0 1])), 'detect flags');

% 4. splitter collapsed: obs2 contributes one row to event 3, not two
pass = check(pass, height(ch) == 3, 'splitter collapsed to one row');

% 5. order independence: swapping inputs gives the same event count
ch2 = multiCaptureHistoryClustered(d2, d1, 'timeBuffer', 3*day, ...
                                   'splitRule', 'overlap', 'verbose', false);
pass = check(pass, height(ch2) == height(ch), 'order independent');

fprintf('\ntestMatchboxSmoke: %s\n', ternary(pass, 'ALL PASS', 'FAILURES ABOVE'));
end

function pass = check(pass, cond, name)
fprintf('  [%s] %s\n', ternary(cond, 'ok', 'XX'), name);
pass = pass && cond;
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
