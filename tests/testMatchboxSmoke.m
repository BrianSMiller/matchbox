function testMatchboxSmoke
% testMatchboxSmoke  Fast invariant checks for the matchbox front door.
%   No external data. Exercises all four methods through matchbox(...) and
%   confirms the core guarantees: one row per event, unique keys, correct
%   detect flags, the default method, and that method-specific parameters
%   are validated rather than silently ignored. Clustered, gridded, and
%   pointProximity are additionally checked for order independence;
%   pairwise is not, since order dependence is an inherent, documented
%   property of that method rather than a bug. Likewise, *why* clustered
%   and pointProximity can disagree on the same data is illustrated in
%   examples/gallery.m (Example 9), not asserted here -- this file checks
%   structure and parameter validation, not "makes a good story".
%   Run with: testMatchboxSmoke
%
% For the full illustrated validation ladder see
% examples/gallery.m.
%
% NOTE: pairwise needs doTimespansOverlap and timespanOverlap from the
% original annotatedLibrary/bsmUtils toolboxes on the path. Clustered,
% gridded, and pointProximity are self-contained (base MATLAB).

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

% --- pairwise, via the front door ----------------------------------------
% Pairwise matches on time AND frequency, unlike clustered/gridded, so this
% fixture (same call type, same band, non-ambiguous) still gives one row
% per event and correct detect flags, even though the matching mechanism
% differs.
pw = matchbox(d1, d2, 'method','pairwise', 'timeBuffer', 3*day, 'verbose', false);
pass = check(pass, height(pw) == numel(unique(pw.key)), 'pairwise unique keys');
pass = check(pass, height(pw) == 3, 'pairwise three events');
[~, pwOrd] = sort(pw.t0);
pass = check(pass, all(pw.detect_observer1(pwOrd)) && ...
                   isequal(pw.detect_observer2(pwOrd)', logical([1 0 1])), ...
                   'pairwise detect flags');

% Pairwise is order dependent BY DESIGN (matching against a growing
% aggregate); unlike clustered/gridded, we do not assert stability under
% reversed observer order here. A dedicated order-dependence demonstration
% lives in examples/gallery.m (Example 3), with a scenario built to make
% the mechanism visible.

% --- pointProximity, via the front door ----------------------------------
% This is NOT the same fixture result as clustered, and that's the point:
% clustered's running-interval-end mechanism keeps a long detection's
% cluster open past its own start, so d1's call 3 [200,212] stays linked
% to BOTH of d2's split fragments (starting at 201 and 209) even though
% 209-201=8s exceeds the 3s buffer -- the link is via each fragment's own
% overlap with the still-open interval, not fragment-to-fragment distance.
% pointProximity has no such extension: it only ever compares consecutive
% sorted points, so d2's second fragment (t0=209) is genuinely 8s from the
% nearest other point (201) and opens its own event. Hand-verified (see
% chat): 4 events, not 3.
pp = matchbox(d1, d2, 'method','pointProximity', 'timeBuffer', 3*day, 'verbose', false);
pass = check(pass, height(pp) == numel(unique(pp.key)), 'pointProximity unique keys');
pass = check(pass, height(pp) == 4, 'pointProximity four events (not three -- see comment)');
[~, ppOrd] = sort(pp.t0);
pass = check(pass, isequal(pp.detect_observer1(ppOrd)', logical([1 1 1 0])) && ...
                   isequal(pp.detect_observer2(ppOrd)', logical([1 0 1 1])), ...
                   'pointProximity detect flags');
pp2 = matchbox(d2, d1, 'method','pointProximity', 'timeBuffer', 3*day, 'verbose', false);
pass = check(pass, height(pp2) == height(pp), 'pointProximity order independent');

% refCol: using 'center' instead of the default 't0' changes which point
% is compared. A parameter-validation check, not an illustration of *why*
% clustered and pointProximity can disagree -- that lives in
% examples/gallery.m (Example 9), the same way pairwise's order dependence
% lives in Example 3 rather than here.
d3 = mk([0]*day, [50]*day);
ppCenter = matchbox(d1, d3, 'method','pointProximity', 'timeBuffer', 3*day, ...
                     'refCol', 'center', 'verbose', false);
pass = check(pass, height(ppCenter) >= 1, 'pointProximity refCol=''center'' runs and returns events');
pass = check(pass, threws(@() matchbox(d1, d2, 'method','pointProximity', ...
                                        'refCol', 'notAColumn', 'verbose', false)), ...
             'pointProximity errors on unknown refCol');

% --- parameter validation through the front door ------------------------
pass = check(pass, threws(@() matchbox(d1, d2, 'method','gridded', 'verbose', false)), ...
             'gridded requires gridStep');
pass = check(pass, threws(@() matchbox(d1, d2, 'method','nonsense', 'verbose', false)), ...
             'unknown method errors');
pass = check(pass, threws(@() matchbox(d1, d2, 'method','clustered', 'gridStep', 60*day)), ...
             'wrong-method param errors, not silently ignored');
pass = check(pass, threws(@() matchbox(d1, d2, 'method','pairwise', 'gridStep', 60*day)), ...
             'pairwise rejects gridded-only param, not silently ignored');
pass = check(pass, threws(@() matchbox(d1, d2, 'method','pointProximity', 'gridStep', 60*day)), ...
             'pointProximity rejects gridded-only param, not silently ignored');

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
