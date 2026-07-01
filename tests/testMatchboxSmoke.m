function testMatchboxSmoke
% testMatchboxSmoke  Fast invariant checks for the matchbox front door.
%   No external data. Exercises both methods through matchbox(...) and
%   confirms the core guarantees: one row per event, unique keys, correct
%   detect flags, order independence, the default method, and that
%   method-specific parameters are validated rather than silently ignored.
%   Run with: testMatchboxSmoke
%
% For the full illustrated validation ladder see
% examples/gallery.m.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));   % put matchbox and the matchers on the path

pass = true;
day  = 1/86400;

% Fixture: 3 calls at t = 10, 100, 200 s. Observer 1 sees all three;
% observer 2 sees calls 1 and 3, and splits call 3 into two boxes.
mk = @(t0,tEnd) table(t0(:), tEnd(:), 26*ones(numel(t0),1), 28*ones(numel(t0),1), ...
                      'VariableNames', {'t0','tEnd','fLow','fHigh'});
d1 = mk([10 100 200]*day, [22 112 212]*day);
d2 = mk([11 201 209]*day, [23 205 214]*day);   % misses call 2, splits call 3

% --- clustered, via the front door --------------------------------------
ch = matchbox(d1, d2, 'method','clustered', 'timeBuffer', 3*day, 'verbose', false);
pass = check(pass, height(ch) == numel(unique(ch.key)), 'clustered unique keys');
pass = check(pass, height(ch) == 3, 'clustered three events');
[~, ord] = sort(ch.t0);
pass = check(pass, all(ch.detect_observer1(ord)) && ...
                   isequal(ch.detect_observer2(ord)', logical([1 0 1])), ...
                   'clustered detect flags');
ch2 = matchbox(d2, d1, 'method','clustered', 'timeBuffer', 3*day, 'verbose', false);
pass = check(pass, height(ch2) == height(ch), 'clustered order independent');

% --- default method is clustered ----------------------------------------
chd = matchbox(d1, d2, 'timeBuffer', 3*day, 'verbose', false);
pass = check(pass, height(chd) == height(ch), 'default method is clustered');

% --- gridded, via the front door ----------------------------------------
% One-minute bins put calls 1 (~10 s), 2 (~100 s), 3 (~200 s) in three
% different bins; observer 2's split of call 3 collapses within the bin.
g = matchbox(d1, d2, 'method','gridded', 'gridStep', 60*day, 'verbose', false);
pass = check(pass, height(g) == numel(unique(g.key)), 'gridded unique keys');
pass = check(pass, height(g) == 3, 'gridded three bins');
[~, gord] = sort(g.t0);
pass = check(pass, all(g.detect_observer1(gord)) && ...
                   isequal(g.detect_observer2(gord)', logical([1 0 1])), ...
                   'gridded detect flags');
g2 = matchbox(d2, d1, 'method','gridded', 'gridStep', 60*day, 'verbose', false);
pass = check(pass, height(g2) == height(g), 'gridded order independent');

% --- parameter validation through the front door ------------------------
pass = check(pass, threws(@() matchbox(d1, d2, 'method','gridded', 'verbose', false)), ...
             'gridded requires gridStep');
pass = check(pass, threws(@() matchbox(d1, d2, 'method','nonsense', 'verbose', false)), ...
             'unknown method errors');
pass = check(pass, threws(@() matchbox(d1, d2, 'method','clustered', 'gridStep', 60*day)), ...
             'wrong-method param errors, not silently ignored');

fprintf('\ntestMatchboxSmoke: %s\n', ternary(pass, 'ALL PASS', 'FAILURES ABOVE'));
end

% -------------------------------------------------------------------------
function tf = threws(fn)
% True if calling fn() raises an error.
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
