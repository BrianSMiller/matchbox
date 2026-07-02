%% Capture History Matching: Synthetic Gallery
% A laddered, illustrated introduction to multi-observer capture-history
% matching. The examples climb a ladder of complexity: each one adds a single
% complication to a scenario whose answer is known in advance, so any
% disagreement is a fault in the matcher and not an opinion about real whales.
% The gallery is meant to be readable by someone meeting these ideas for the
% first time, so the first two sections give the background before any code
% runs.
%
% *To publish to HTML:*
%
%   publish('gallery.m')
%
% B. Miller, AAD, 2026

close all

%% Background
% A *capture history* records, for one real event, which of several
% independent observers detected it. Here the event is an acoustic call and
% the observers are analysts and automated detectors. Each row is a call,
% each column is an observer, and each entry says whether that observer
% detected that call. The idea comes from mark-recapture and double-observer
% survey methods, where comparing who saw what lets you estimate how often
% things are missed and correct counts accordingly.
%
% In passive acoustics this feeds two distinct jobs, and the distinction
% matters throughout the gallery:
%
% 1. *Detection functions for call density estimation.* How detection
%    probability falls with range or signal-to-noise ratio, so a count of
%    detections becomes a density of animals. This is the Common Ground
%    protocol (Miller et al. 2026, Methods in Ecology and Evolution; the
%    |callDensity| R package).
% 2. *Detector characterisation.* How a detector performs against analysts
%    or other detectors, in the usual precision and recall terms.
%
% Building a capture history requires *matching*: deciding when a detection
% from one observer is the same call as a detection from another. In
% continuous time, with imperfect boxes drawn around calls, this is the hard
% part. Four things go wrong, and each has its own example below:
%
%   missed          an observer did not detect a call that was there
%   false positive  a detection with no real call behind it
%   splitting       one observer draws several boxes over a single call
%   lumping         one observer draws a single box over several calls
%
% Missed detections and false positives are unavoidable and are exactly what
% we want to measure. Splitting is a nuisance the matcher can undo, because
% the split boxes still point at one call. Lumping destroys information and
% cannot be undone after the fact, which is a theme the gallery returns to.
%
% Most of the gallery uses one matching algorithm, *temporal single-linkage
% clustering*. All detections from all observers are pooled and sorted in
% time, and a single forward pass groups them into events, opening a new
% event whenever a gap larger than |timeBuffer| appears. It is order
% independent and needs no pairwise joins. Its strengths and its one clear
% failure mode both appear below. The final example introduces a second
% algorithm, a *gridded* matcher, at the point where clustering runs out of
% road.

%% Reading the figures
% Every example draws a timeline. Time runs left to right in seconds. There
% is one row per observer.
%
%   coloured bar   a detection, from its start to its end time. The colour
%                  identifies the true call it belongs to, so bars of the
%                  same colour are the same call seen by different observers.
%   grey bar       a false positive: a detection that belongs to no call.
%   thicker bar    a lumped box, one the generator drew over more than one
%                  call (appears in the lumping example).
%   shaded band    a recovered event. Every bar inside one band was assigned
%                  to the same event by the matcher. Alternate events are
%                  shaded so neighbours stay distinct.
%   bottom tick    a true call centre, coloured to match its call. This is
%                  the ground truth the matcher never sees. A tick with no
%                  bars above it is a call every observer missed.
%
% So the shaded bands are the matcher's answer, and the colours are the
% truth. When they agree, each band holds exactly one colour. A band holding
% two colours is a merge: two real calls collapsed into one event.

%% Setup
% matchbox lives in the repo root, one level up from this examples folder, so
% we add that to the path relative to this file. Each example calls matchbox
% directly, so the reader sees exactly which algorithm and parameters produced
% each result. Clustered matching is the default method, so most examples pass
% only a timeBuffer; the final example names both methods to compare them.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'), '-begin');

timeBuffer = 3;    % seconds. Detections separated by more than this open a
                   % new event. In the real pipeline this is in days.

fprintf('Buffer = %g s | splitRule = overlap\n', timeBuffer);

%% Example 0: Perfect agreement
% The plumbing test. Two observers detect every call at the same time. There
% is nothing to disagree about, so the matcher should return one event per
% call with both observers present. If this fails, nothing below is
% meaningful.

p = defaults('zcall');
p.nCalls = 12; p.nObs = 2;
p.pDetect = ones(p.nCalls, p.nObs);     % everyone detects everything

[tables, truth] = genScenario(p);
ch  = matchbox(tables{:}, 'timeBuffer', timeBuffer, 'verbose', false);
res = checkScenario(ch, truth);
reportRung('0  perfect agreement', res);
plotScenario(tables, ch, truth, 'Example 0: perfect agreement');

%% Example 1: Partial detection
% Real observers miss calls. Here three observers each detect a random 70%
% of calls, independently. The recovered detection matrix must reproduce the
% pattern of hits and misses exactly. This is the capture history doing its
% actual job.
%
% Watch for a call that every observer missed. With three observers at 70%
% each, a call is missed by all three about 3% of the time, so across two
% dozen calls you usually get one. It has an all-zero capture history, so it
% cannot be a row in the table and shows only as a bottom tick with no bars
% above it. This is not a failure. It is the reason capture-recapture is
% worth the trouble: the frequencies of calls seen by one, two, and three
% observers let you estimate how many were seen by none, which is the number
% you most want and can never count directly. The printout shows those
% frequencies, and the missed-by-all count beside them.

p = defaults('zcall');
p.nCalls = 24; p.nObs = 3;
p.pDetect = 0.7;

[tables, truth] = genScenario(p);
ch  = matchbox(tables{:}, 'timeBuffer', timeBuffer, 'verbose', false);
res = checkScenario(ch, truth);
reportRung('1  partial detection', res);
plotScenario(tables, ch, truth, 'Example 1: partial detection');

%% Example 2: Timing jitter and order independence
% Observers rarely agree on a call's start to the second. Here their boxes
% are offset by a few seconds. For well-separated calls this must change
% nothing, because boxes of the same call still overlap. We also shuffle the
% order the tables are passed in and confirm the event structure is
% identical. That is the synthetic version of the 123-versus-321 test on the
% real Casey data, where the old pairwise matcher gave different answers
% depending on observer order and this one does not.

p = defaults('zcall');
p.nCalls = 24; p.nObs = 3;
p.pDetect = 0.7; p.timeJitter = 3;      % seconds of start-time disagreement

[tables, truth] = genScenario(p);
ch  = matchbox(tables{:}, 'timeBuffer', timeBuffer, 'verbose', false);
res = checkScenario(ch, truth);
reportRung('2  timing jitter', res);

% Order independence: match the same tables in a shuffled order and compare
% the event structure, using the true-call content of each event (which does
% not depend on which column an observer landed in).
ord  = randperm(truth.nObs);
chSh = matchbox(tables{ord}, 'timeBuffer', timeBuffer, 'verbose', false);
ev1  = computeEventIds(ch,   truth.nObs);
ev2  = computeEventIds(chSh, truth.nObs);
same = ev1.nEvents == ev2.nEvents && isequal(ev1.sortedIds, ev2.sortedIds);
fprintf('   order-independent: %s\n', tf(same, 'yes', 'NO'));
plotScenario(tables, ch, truth, 'Example 2: timing jitter');

%% Example 3: False positives
% This is the case that dominates automated detection. Low-precision
% detectors report many spurious detections, because there are many
% low-SNR calls to be fooled by. Observer 3 here is such a detector. Its
% false positives must form their own events and must never attach
% themselves to a real call.

p = defaults('zcall');
p.nCalls = 24; p.nObs = 3;
p.pDetect = 0.7; p.timeJitter = 3;
p.nFP = [4 4 18];                       % observer 3 is low precision

[tables, truth] = genScenario(p);
ch  = matchbox(tables{:}, 'timeBuffer', timeBuffer, 'verbose', false);
res = checkScenario(ch, truth);
reportRung('3  false positives', res);
plotScenario(tables, ch, truth, 'Example 3: false positives');

%% Example 4: Splitting
% Observer 3 now sometimes reports one call as two shorter boxes. Because
% both boxes still overlap the same call, the matcher's same-observer
% collapse folds them back to one row per event, and the event count and
% detection matrix are unchanged. Splitting is a nuisance, not a loss:
% nothing about the truth was destroyed.

p = defaults('zcall');
p.nCalls = 24; p.nObs = 3;
p.pDetect = 0.85; p.timeJitter = 3;
p.pSplit = [0 0 0.5];                   % observer 3 is the splitter

[tables, truth] = genScenario(p);
ch  = matchbox(tables{:}, 'timeBuffer', timeBuffer, 'verbose', false);
res = checkScenario(ch, truth);
reportRung('4  splitting', res);
fprintf('   splits generated: %d | events still equal detected calls: %s\n', ...
    truth.nSplits, tf(res.nCallsRecovered == res.nCallsExpected, 'yes', 'NO'));
plotScenario(tables, ch, truth, 'Example 4: splitting');

%% Example 5: Lumping, and why it must be fixed upstream
% Observer 1 now sometimes draws one box over two adjacent calls. This is the
% pathology we found in analyst a2 at Casey 2019. Unlike splitting it cannot
% be undone, because the fact that the box held two calls was never recorded.
% Lumping carries two costs, one for each application from the Background:
%
% 1. *Detector characterisation.* The lumped box bridges two calls into one
%    long event. The dependable signature is event duration, exactly as on
%    the real data where the lump events formed a tail past 40 s. We detect
%    every lump this way.
% 2. *Co-observer corruption.* Because the lump bridges the two calls into a
%    single event, the separate detections that the other observers made of
%    those two calls now sit in the same event and collapse to one row each.
%    Their capture histories are quietly damaged. That lost-detection count
%    is the real price of a missing "one box per call" instruction.
%
% The |nCalls| annotation the generator puts on the lumped box supports the
% density correction (a true positive worth two calls) for that observer,
% but it cannot restore what the co-observers lost. The fix belongs in the
% annotation protocol, not in the matcher.

p = defaults('zcall');
p.nCalls = 24; p.nObs = 3;
p.pDetect = [1 0.9 0.9];                % obs2/obs3 see calls individually
p.timeJitter = 3;
p.pLump = [0.3 0 0];                    % only observer 1 lumps, like analyst a2

[tables, truth] = genScenario(p);
ch  = matchbox(tables{:}, 'timeBuffer', timeBuffer, 'verbose', false);

% Cost 1: detect lumps by duration, the same diagnostic used on real data.
durS       = ch.tEnd - ch.t0;           % event durations, seconds
longThresh = p.callDur + 6*p.timeJitter + 5;  % longer than any single call's envelope
nLong      = sum(durS > longThresh);

% Cost 2: how many real detections were swallowed by collapse. Every real
% detection generated, minus every real detection surviving in the table,
% is the number lost. With no splitting in this example the loss is all lumping.
nPooledReal  = sum(cellfun(@(t) sum(t.trueCall > 0), tables));
detCols      = ch.Properties.VariableNames(startsWith(ch.Properties.VariableNames,'detect_observer'));
nDetectCells = sum(sum(ch{:, detCols} == 1));
collapseLoss = nPooledReal - nDetectCells;

fprintf('\nExample 5  lumping  [demonstration]\n');
fprintf('   lumps generated: %d | long events (>%.0f s): %d  -> duration catches every lump: %s\n', ...
    truth.nLumps, longThresh, nLong, tf(nLong == truth.nLumps, 'yes', 'NO'));
fprintf('   co-observer detections swallowed by lump-bridged events: %d\n', collapseLoss);
plotScenario(tables, ch, truth, 'Example 5: lumping (long bridged events)');

%% Example 6: Chorus regime, where event-per-call breaks down
% Everything so far assumed calls far enough apart to tell one from the next.
% Now the calls are close-spaced, a chorus of several animals rather than one
% caller. Every box is honest: no lumping and no splitting. But distinct
% calls sit within a jitter-width of each other, so neighbouring boxes
% overlap. This is the fin-pulse regime, and it is the boundary of the
% clustering approach.
%
% Two matchers answer two different questions here, and the point of this
% example is the difference between the questions, not a contest between the
% methods.
%
% *Clustered* matching asks: which detections belong to the same call?
% With overlapping boxes it cannot separate neighbours. Single-linkage
% bridges genuinely distinct calls into one event even at a zero buffer, and
% widening the buffer only merges more. No non-negative buffer recovers one
% event per call, so the sweep keeps falling as the buffer grows and never
% settles on a plateau.
%
% *Gridded* matching asks a different, well-posed question: within each fixed
% time bin, which observers were present? It does not try to recover
% individual calls. It reports presence at a resolution you choose, the way an
% occupancy analysis chooses a cell size. Its event count also depends on the
% bin width, but that dependence is a choice of resolution, not a failed
% search. Here the grid is 15 s, a little wider than the 14 s mean call
% spacing.
%
% Clustered has a third knob worth knowing. A negative buffer requires two
% detections to overlap by at least its magnitude before they link, so it
% fragments loosely joined chains and drives the event count up, toward the
% per-call number and past it. The clustered sweep below runs into negative
% buffers, and somewhere among them the clustered count crosses the dashed
% line and lands on the number of calls that were detected. That landing is a
% trap. The right number of events is not the right set of calls. Because this
% scenario is synthetic we can prove it: at that buffer the count is right
% while the capture history still holds merged events and calls fragmented
% across two events. On real data, where the truth is hidden, event duration
% is the stand-in check. A clean event lasts about as long as one call, so
% events far longer flag merges and far shorter flag fragments.
%
% The dashed line on each sweep is the number of true calls at least one
% observer detected, the event count a perfect matcher would return. Clustered
% sits below it at every non-negative buffer and falls further as the buffer
% grows. Gridded meets it only when the bin is tuned near the call rate, which
% is exactly the information a chorus hides.

p = defaults('chorus');
p.nCalls = 40; p.nObs = 3;
p.pDetect = 0.8;

[tables, truth] = genScenario(p);
nDet = numel(truth.detectedCalls);      % distinct calls seen by someone

% Clustered at its most favourable setting, a zero buffer. Even here it
% bridges neighbouring calls into shared events.
chC = matchbox(tables{:}, 'method','clustered', 'timeBuffer', 0, 'verbose', false);
evC = computeEventIds(chC, truth.nObs);

% Gridded at a 15 s bin, a little wider than the 14 s mean call spacing.
gridStep = 15;
chG = matchbox(tables{:}, 'method','gridded', 'gridStep', gridStep, 'verbose', false);
evG = computeEventIds(chG, truth.nObs);

fprintf('\nExample 6  chorus  [head-to-head]\n');
fprintf('   %d true calls detected by one or more observers.\n', nDet);
fprintf('   clustered, buffer 0 s : %3d events, %2.0f%% hold >1 call (unwanted merges)\n', ...
    evC.nEvents, 100*mean(evC.merged));
fprintf('   gridded,   grid %2g s  : %3d events, %2.0f%% hold >1 call (bin coarser than call rate)\n', ...
    gridStep, evG.nEvents, 100*mean(evG.merged));

% Sweeps. Clustered over timeBuffer (including negative buffers, which require
% overlap to link), gridded over gridStep. Both counts move with their
% parameter, but for different reasons: clustered is searching for a plateau
% that is not there, gridded is being read at different resolutions.
bufSecs  = [-6 -4 -3 -2 -1 0 1 2 3 5 8];
nEvBuf   = arrayfun(@(b) height(matchbox(tables{:}, 'method','clustered', ...
    'timeBuffer', b, 'verbose', false)), bufSecs);

gridSecs = [8 12 15 20 30];
nEvGrid  = arrayfun(@(g) height(matchbox(tables{:}, 'method','gridded', ...
    'gridStep', g, 'verbose', false)), gridSecs);

fprintf('   clustered buffer (s): '); fprintf('%6g', bufSecs);  fprintf('\n');
fprintf('   events              : '); fprintf('%6g', nEvBuf);   fprintf('\n');
fprintf('   gridded grid (s)    : '); fprintf('%6g', gridSecs); fprintf('\n');
fprintf('   events              : '); fprintf('%6g', nEvGrid);  fprintf('\n');

% Count is not correctness. Tune the clustered buffer to the negative value
% whose event count is closest to the number of calls detected (the dashed
% line), then, because the truth is known here, measure what that capture
% history actually got wrong. The count is right while merges and fragmented
% calls remain. Duration is the same story a real dataset would show without
% any truth to check against.
negList  = bufSecs(bufSecs < 0);
[~, im]  = min(abs(nEvBuf(bufSecs < 0) - nDet));
bufMatch = negList(im);
chMatch  = matchbox(tables{:}, 'method','clustered', 'timeBuffer', bufMatch, 'verbose', false);
evM      = computeEventIds(chMatch, truth.nObs);

realIds  = evM.realId(~isnan(evM.realId));           % true call behind each real event
nFrag    = sum(arrayfun(@(c) sum(realIds == c) > 1, unique(realIds)));  % calls split across events
nMerge   = sum(evM.merged);

fprintf('   tuned clustered buffer %g s: %d events, against %d calls detected (count on target)\n', ...
    bufMatch, height(chMatch), nDet);
fprintf('   but the capture history is still wrong: %d merged events, %d fragmented calls\n', ...
    nMerge, nFrag);
fprintf('   duration check (real-data proxy): one call ~%g s | median event  clustered %.1f s  gridded %.1f s\n', ...
    p.callDur, median(chMatch.tEnd - chMatch.t0), median(chG.tEnd - chG.t0));

% Two timelines on the same data, drawn as separate figures so each publishes
% under its own heading. Clustered bridges neighbours into shared bands;
% gridded cuts the same detections into fixed bins.
plotScenario(tables, chC, truth, 'Example 6: clustered matcher, buffer 0 s');
plotScenario(tables, chG, truth, sprintf('Example 6: gridded matcher, %g s bins', gridStep));

% Two sweeps side by side. Left: clustered never plateaus. Right: gridded
% varies smoothly with the bin width you choose.
figure('Units','pixels','Position',[50 50 1000 320]);
tiledlayout(1, 2, 'Padding','compact', 'TileSpacing','compact');

nexttile;
plot(bufSecs, nEvBuf, '-o', 'LineWidth', 1.2); grid on
yline(nDet, '--', 'true calls detected');
xlabel('timeBuffer (s)'); ylabel('number of events');
title('clustered: no plateau', 'FontWeight','bold');

nexttile;
plot(gridSecs, nEvGrid, '-o', 'LineWidth', 1.2); grid on
yline(nDet, '--', 'true calls detected');
xlabel('gridStep (s)'); ylabel('number of events');
title('gridded: count set by chosen resolution', 'FontWeight','bold');

fprintf('\n=== gallery complete ===\n');

% Helper functions (scenario generation, checking, plotting) live in
% examples/private/ so this file stays a pure script, which publishes cleanly.
