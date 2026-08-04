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
% # *Detection functions for call density estimation.* How detection
%    probability falls with range or signal-to-noise ratio, so a count of
%    detections becomes a density of animals. This is the Common Ground
%    protocol (Miller et al. 2026, Methods in Ecology and Evolution; the
%    |callDensity| R package).
% # *Detector characterisation.* How a detector performs against analysts
%    or other detectors, in the usual precision and recall terms.
%
% Building a capture history requires *matching*: deciding when a detection
% from one observer is the same call as a detection from another. In
% continuous time, with imperfect boxes drawn around calls, this is the hard
% part. Four things go wrong, and each has its own example below:
%
%  missed           an observer did not detect a call that was there
%  false positive   a detection with no real call behind it
%  splitting        one observer draws several boxes over a single call
%  lumping          one observer draws a single box over several calls
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
% failure mode both appear below. Example 7 introduces a second algorithm,
% a *gridded* matcher, at the point where clustering runs out of road. The
% final example introduces a third, *pointProximity*, which links on a
% single reference point rather than interval overlap -- a different
% question again, not a better answer to the same one.

%% Reading the figures
% Every example draws a timeline. Time runs left to right in seconds. There
% is one row per observer.
%
% 
%  coloured bar    a detection, from its start to its end time. The colour
%                  identifies the true call it belongs to, so bars of the
%                  same colour are the same call seen by different observers.
%  grey bar        a false positive: a detection that belongs to no call.
%  thicker bar     a lumped box, one the generator drew over more than one
%                  call (appears in the lumping example).
%  shaded band     a recovered event. Every bar inside one band was assigned
%                  to the same event by the matcher. Alternate events are
%                  shaded so neighbours stay distinct.
%  bottom tick     a true call centre, coloured to match its call. This is
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
% of calls, independently. The recovered detection matrix should reproduce the
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

%% Example 2: Timing jitter 
% Observers rarely agree on a call's start to the second. Here their boxes
% are offset (potentially by a few seconds on long calls). Ideally this
% will not change the results because boxes of the same call still overlap. 
% 
p = defaults('zcall');
p.nCalls = 24; p.nObs = 3;
p.pDetect = 0.7; p.timeJitter = 3;      % seconds of start-time disagreement

[tables, truth] = genScenario(p);
ch  = matchbox(tables{:}, 'timeBuffer', timeBuffer, 'verbose', false);
res = checkScenario(ch, truth);
reportRung('2  timing jitter', res);
plotScenario(tables, ch, truth, 'Example 2: timing jitter');

%% Example 3: Order dependence of the pairwise matcher
% Two calls, call A near 20 s and call B near 40 s, sit twelve seconds apart.
% Nothing links them except one lumped box: observer 3 drew a single
% annotation over both, the a2 pathology from Casey 2019. That box overlaps
% observer 1's box on A and observer 2's box on B, so it bridges them.
%
% The clustered matcher pools every detection, sorts by time, and cuts on
% gaps. The bridge chains A to B into one event, and because pooling ignores
% who contributed what, it returns that same one event whichever observer is
% passed first. It is stable.
%
% The pairwise matcher builds a growing aggregate and matches each new
% observer against it. Order now decides the answer. Passed 1, 2, 3, the two
% calls seed separate events and the bridge, arriving last, attaches to the
% one it overlaps more, leaving two events. Passed 3, 2, 1, the bridge seeds
% the aggregate first, then A and B both merge onto it, leaving one. Same
% detections, same boxes, two different capture histories. This is a
% structural property of matching against a growing aggregate, not a bug --
% see help multiCaptureHistoryPairwise.
%
% Four figures follow. The two clustered timelines are identical. The two
% pairwise timelines differ, and the difference is visible without reading the
% prose: forward keeps B separate, reversed swallows it. The pairwise path
% also needs doTimespansOverlap and timespanOverlap from the original
% toolbox.

vn = {'t0','tEnd','fLow','fHigh','snr','trueCall','nCalls'};
band = [15 28];
tables = { ...
    table(16, 24, band(1), band(2), 10, 1, 1, 'VariableNames', vn), ... % obs1: call A
    table(36, 44, band(1), band(2), 10, 2, 1, 'VariableNames', vn), ... % obs2: call B
    table(18, 41, band(1), band(2),  8, 1, 2, 'VariableNames', vn) };   % obs3: lump A+B

% Ground truth for this hand-built scenario, in the same shape genScenario
% returns. Observer 3's lump means it detected both A and B, so both columns
% of its row in D are true.
truth = struct();
truth.D             = logical([1 0 1; 0 1 1]);   % rows = calls, cols = observers
truth.tCentre       = [20; 40];
truth.nCalls        = 2;
truth.nObs          = 3;
truth.detectedCalls = find(any(truth.D, 2));
truth.nSplits       = 0;
truth.nLumps        = 1;

ord = fliplr(1:truth.nObs);            % reversed observer order

% Clustered: original and reversed. sortedIds is compared, not the raw table,
% because reversing observers permutes the detect_observer columns while
% leaving the event structure untouched.
chC1 = matchbox(tables{:},   'timeBuffer', timeBuffer, 'verbose', false);
chC2 = matchbox(tables{ord}, 'timeBuffer', timeBuffer, 'verbose', false);
evC1 = computeEventIds(chC1, truth.nObs);
evC2 = computeEventIds(chC2, truth.nObs);
clusterSame = evC1.nEvents == evC2.nEvents && isequal(evC1.sortedIds, evC2.sortedIds);

% Pairwise: original and reversed.
chP1 = multiCaptureHistoryPairwise(tables{:});
chP2 = multiCaptureHistoryPairwise(tables{ord});
evP1 = computeEventIds(chP1, truth.nObs);
evP2 = computeEventIds(chP2, truth.nObs);
pairSame = evP1.nEvents == evP2.nEvents && isequal(evP1.sortedIds, evP2.sortedIds);

fprintf('\nExample 3  order dependence\n');
fprintf('   clustered: %d events forward, %d reversed  -> stable: %s\n', ...
    evC1.nEvents, evC2.nEvents, tf(clusterSame, 'yes', 'NO'));
fprintf('   pairwise:  %d events forward, %d reversed  -> stable: %s\n', ...
    evP1.nEvents, evP2.nEvents, tf(pairSame, 'yes', 'NO'));
fprintf('   demonstration valid (clustered stable, pairwise not): %s\n', ...
    tf(clusterSame && ~pairSame, 'yes', 'NO'));

plotScenario(tables, chC1, truth, 'Example 3: clustered, forward order');
plotScenario(tables, chC2, truth, 'Example 3: clustered, reversed order (identical)');
plotScenario(tables, chP1, truth, 'Example 3: pairwise, forward order');
plotScenario(tables, chP2, truth, 'Example 3: pairwise, reversed order (differs)');
%% Example 4: False positives
% This is the case that dominates automated detection. Low-precision
% detectors report many spurious detections. Observer 3 here is such a 
% detector. Ideally, the false positives will form their own events and not 
% attach themselves to a real call, which would confound the capture 
% history.

p = defaults('zcall');
p.nCalls = 24; p.nObs = 3;
p.pDetect = 0.7; p.timeJitter = 3;
p.nFP = [4 4 18];                       % observer 3 is low precision

[tables, truth] = genScenario(p);
ch  = matchbox(tables{:}, 'timeBuffer', timeBuffer, 'verbose', false);
res = checkScenario(ch, truth);
reportRung('4  false positives', res);
plotScenario(tables, ch, truth, 'Example 4: false positives');

%% Example 5: Splitting
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
plotScenario(tables, ch, truth, 'Example 5: splitting');

%% Example 6: Lumping, and why it must be fixed upstream
% Observer 1 now sometimes draws one box over two adjacent calls. This is the
% pathology we found in analyst a2 at Casey 2019. Unlike splitting it cannot
% be undone, because the fact that the box held two calls was never recorded.
% Lumping carries two costs:
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
% If the annotation generator can assign a number of calls, |nCalls| to
% each annotation, then the lumped box can still be used for density
% estimation with a correction (that true positive is worth two calls).
% However, this correction cannot restore what the co-observers lost. So
% this post-hoc correction does not fully rectify lumped  calls. Instead,
% the fix belongs in the annotation protocol: ensure that observers
% strictly adhere to a protocol of "one call per annotation" (i.e. NO
% lumping).

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

fprintf('\nExample 6:  lumping  [demonstration]\n');
fprintf('   lumps generated: %d | long events (>%.0f s): %d  -> duration catches every lump: %s\n', ...
    truth.nLumps, longThresh, nLong, tf(nLong == truth.nLumps, 'yes', 'NO'));
fprintf('   co-observer detections swallowed by lump-bridged events: %d\n', collapseLoss);
plotScenario(tables, ch, truth, 'Example 6: lumping (long bridged events)');

%% Example 7: Heavy overlap/chorus regime, where event-per-call breaks down
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
% search. Here the grid is 15 s, a little wider than the mean call spacing.
%
% The dashed line on each sweep is the number of true calls at least one
% observer detected, the event count a perfect matcher would return. Clustered
% sits below it at every non-negative buffer and falls further as the buffer
% grows. Gridded meets it only when the bin width is tuned near the mean call
% spacing, which is exactly the information a chorus hides.

p = defaults('chorus');
p.nCalls = 40; p.nObs = 3;
p.pDetect = 0.8;

[tables, truth] = genScenario(p);
nDet = numel(truth.detectedCalls);      % distinct calls seen by someone

% Clustered at its most favourable setting, a zero buffer. Even here it
% bridges neighbouring calls into shared events.
chC = matchbox(tables{:}, 'method','clustered', 'timeBuffer', 0, 'verbose', false);
evC = computeEventIds(chC, truth.nObs);

% Gridded at a bin a little wider than the mean call spacing.
gridStep = 15;
chG = matchbox(tables{:}, 'method','gridded', 'gridStep', gridStep, 'verbose', false);
evG = computeEventIds(chG, truth.nObs);

fprintf('\nExample 7  chorus  [head-to-head]\n');
fprintf('   %d true calls detected by one or more observers.\n', nDet);
fprintf('   true call spacing: mean %.1f s\n', mean(diff(truth.tCentre)));
fprintf('   clustered, buffer 0 s : %3d events, %2.0f%% hold >1 call (unwanted merges)\n', ...
    evC.nEvents, 100*mean(evC.merged));
fprintf('   gridded,   grid %2g s  : %3d events, %2.0f%% hold >1 call (bin coarser than call rate)\n', ...
    gridStep, evG.nEvents, 100*mean(evG.merged));

% Sweeps. Clustered over non-negative timeBuffer values; gridded over gridStep.
% Both counts move with their parameter, but for different reasons: clustered
% is searching for a per-call plateau that does not exist here; gridded is
% being read at different resolutions.
bufSecs  = [0 1 2 3 5 8];
nEvBuf   = arrayfun(@(b) height(matchbox(tables{:}, 'method','clustered', ...
    'timeBuffer', b, 'verbose', false)), bufSecs);

gridSecs = [8 12 15 20 30];
nEvGrid  = arrayfun(@(g) height(matchbox(tables{:}, 'method','gridded', ...
    'gridStep', g, 'verbose', false)), gridSecs);

fprintf('   clustered buffer (s): '); fprintf('%6g', bufSecs);  fprintf('\n');
fprintf('   events              : '); fprintf('%6g', nEvBuf);   fprintf('\n');
fprintf('   gridded grid (s)    : '); fprintf('%6g', gridSecs); fprintf('\n');
fprintf('   events              : '); fprintf('%6g', nEvGrid);  fprintf('\n');

% Two timelines on the same data, drawn as separate figures so each publishes
% under its own heading. Clustered bridges neighbours into shared bands;
% gridded cuts the same detections into fixed bins.
plotScenario(tables, chC, truth, 'Example 7: clustered matcher, buffer 0 s');
plotScenario(tables, chG, truth, sprintf('Example 7: gridded matcher, %g s bins', gridStep));

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

%% Example 8: Negative buffers, and why count is not correctness
% The clustered sweep in example 7 stopped at zero. Below zero, a negative
% buffer requires two detections to *overlap* by at least its magnitude before
% they link. This fragments loosely joined chains and drives the event count
% upward, past the per-call number and potentially back toward the reference
% line. That recovery is not necessarily correct, and can be a trap.
%
% Here we run the same chorus scenario and sweep into negative buffers.
% Somewhere in that sweep the event count lands on the number of calls that
% at least one observer detected. The count looks right. The capture history
% is not: it still holds merged events and calls fragmented across two rows.
% Because this scenario is synthetic we can prove it. We find the
% best-matching negative buffer automatically, measure the remaining errors,
% and compare event duration against the known call duration as the same check
% a practitioner would run on real data where the truth is hidden.
%
% Neither this example nor example 7 ends with a method declared correct.
% Clustered matching, at any buffer, cannot separate calls that overlap in
% time. Gridded matching sidesteps that question: it reports which observers
% were active in each bin, not which calls they heard. In real Southern Ocean
% choruses, calls from different individuals overlap by arbitrary amounts.
% The two algorithms here represent the current toolkit. Neither resolves the
% general overlapping-call case, and that remains an open problem.

% Reuse the same scenario from example 7.
negBufSecs = [-8 -6 -4 -3 -2 -1 0];
nEvNeg = arrayfun(@(b) height(matchbox(tables{:}, 'method','clustered', ...
    'timeBuffer', b, 'verbose', false)), negBufSecs);

fprintf('\nExample 8  negative buffers  [count vs correctness]\n');
fprintf('   reference: %d calls detected by one or more observers.\n', nDet);
fprintf('   clustered buffer (s): '); fprintf('%6g', negBufSecs); fprintf('\n');
fprintf('   events              : '); fprintf('%6g', nEvNeg);    fprintf('\n');

% Find the negative buffer whose count is closest to nDet.
[~, im]  = min(abs(nEvNeg - nDet));
bufMatch = negBufSecs(im);
chMatch  = matchbox(tables{:}, 'method','clustered', 'timeBuffer', bufMatch, 'verbose', false);
evM      = computeEventIds(chMatch, truth.nObs);

realIds = evM.realId(~isnan(evM.realId));
nFrag   = sum(arrayfun(@(c) sum(realIds == c) > 1, unique(realIds)));
nMerge  = sum(evM.merged);

fprintf('   best-matching buffer %g s: %d events vs %d calls detected\n', ...
    bufMatch, height(chMatch), nDet);
fprintf('   merged events: %d | fragmented calls: %d\n', nMerge, nFrag);
fprintf('   duration check: one call ~%g s | median event at tuned buffer %.1f s\n', ...
    p.callDur, median(chMatch.tEnd - chMatch.t0));

% Sweep figure: negative buffers drive the count up, cross the reference, and
% keep climbing. The crossing is not a solution.
figure('Units','pixels','Position',[50 50 560 320]);
plot(negBufSecs, nEvNeg, '-o', 'LineWidth', 1.2); grid on
yline(nDet, '--', 'true calls detected');
xlabel('timeBuffer (s)'); ylabel('number of events');
title('negative buffers: count crosses reference, history does not', 'FontWeight','bold');

% Timeline at the tuned buffer, alongside the gridded result for comparison.
plotScenario(tables, chMatch, truth, sprintf('Example 8: clustered, buffer %g s (count-matched)', bufMatch));
plotScenario(tables, chG,     truth, sprintf('Example 8: gridded, %g s bins (same data)', gridStep));

%% Example 9: One point vs two -- clustered and pointProximity disagree
% Everything above used the clustered matcher (or, in example 7-8,
% clustered vs gridded). matchbox has a fourth method, pointProximity,
% which links detections by a single reference point (default the start
% time) within timeBuffer of each other, rather than by interval overlap.
% One endpoint compared, not two -- that's the whole difference from
% clustered, and it has a real consequence for imprecise detections.
%
% Observer 1 here is precise: three short calls, A, B, and C, each drawn
% tight to the true call. Observer 2 is not: a single wide box from 0 to
% 50 s, the kind of loose, over-broad detection a low-precision automated
% detector sometimes produces. That box's INTERVAL genuinely overlaps call
% A (10-22 s sits inside 0-50 s), but its START time (0 s) sits 10 s away
% from call A's own start time (10 s) -- farther than the 3 s buffer used
% throughout this gallery.
%
% Clustered links on interval overlap, so it credits observer 2's box to
% call A: one merged event, plus B and C alone, three events total. It
% does not care that observer 2's box started ten seconds early, only that
% the two boxes overlap in time.
%
% pointProximity links on start-time distance alone. Ten seconds exceeds
% the buffer, so it does NOT credit observer 2's box to call A. Observer
% 2's box opens its own event instead: four events total, one of them
% looking exactly like a spurious extra detection even though it is
% genuinely, if imprecisely, call A.
%
% Neither answer is simply "correct". Clustered is more forgiving of
% timing imprecision as long as the boxes truly overlap; pointProximity is
% stricter about a specific instant and blind to duration and overlap
% entirely. Which one you want depends on what a "match" should mean for
% your data -- and this is exactly why pointProximity exists as its own
% method rather than a variant flag on clustered: the two are answering
% different questions, the same way clustered and gridded do in example 7.
%
% This example is deliberately table-only, no timeline figure. The shared
% timeline plot used everywhere else shades events by alternating index,
% purely for visual separation, not as a merge indicator -- and the very
% first chronological event (which is what the merge is, here, since
% observer 2's box starts at t=0) can never land on a shaded index. Worse,
% pointProximity can legitimately produce two SEPARATE events with
% overlapping time envelopes, something clustered/gridded structurally
% cannot, and the shared plot draws each event's shaded region
% independently, so overlapping envelopes visually blend into what looks
% like one merged band whether or not they actually are. Rather than
% fight a visualisation built for an assumption pointProximity doesn't
% satisfy, the table below reads the actual key matchbox assigned to each
% detection directly -- the real answer, not an inference from shading.

vn = {'t0','tEnd','fLow','fHigh','snr','trueCall','nCalls'};
band = [26 28];
tables = { ...
    table([10;100;200], [22;112;212], band(1)*ones(3,1), band(2)*ones(3,1), ...
          10*ones(3,1), [1;2;3], ones(3,1), 'VariableNames', vn), ...  % obs1: precise A, B, C
    table(0, 50, band(1), band(2), 6, 1, 1, 'VariableNames', vn) };    % obs2: one wide box, truly only A

chC  = matchbox(tables{:}, 'method','clustered',     'timeBuffer', timeBuffer, 'verbose', false);
chPP = matchbox(tables{:}, 'method','pointProximity', 'timeBuffer', timeBuffer, 'verbose', false);

fprintf('\nExample 9  point vs interval  [method comparison]\n');
fprintf('   observer 2''s box: [0, 50] s | call A: [10, 22] s | gap between start times: 10 s | buffer: %g s\n', ...
    timeBuffer);
fprintf('   clustered      : %d events\n', height(chC));
fprintf('   pointProximity : %d events\n', height(chPP));

% Event key assigned to each detection, read directly from matchbox's own
% output -- not a description of a figure, the actual answer.
detections = { ...
    'obs1 call A (t0=10)',  1, 10
    'obs1 call B (t0=100)', 1, 100
    'obs1 call C (t0=200)', 1, 200
    'obs2 wide box (t0=0)', 2, 0  };

fprintf('\n   %-24s %12s %14s\n', 'detection', 'clustered key', 'pointProx key');
for i = 1:size(detections, 1)
    label  = detections{i,1};
    obsIdx = detections{i,2};
    t0val  = detections{i,3};
    colC  = sprintf('t0_observer%d', obsIdx);
    kC  = chC.key( abs(chC.(colC)  - t0val) < 1e-9);
    kPP = chPP.key(abs(chPP.(colC) - t0val) < 1e-9);
    fprintf('   %-24s %12d %14d\n', label, kC, kPP);
end
fprintf(['   -> clustered: obs2''s wide box shares a key with call A (merged).\n' ...
         '   -> pointProximity: obs2''s wide box has its own key, distinct from call A.\n']);

fprintf('\n=== gallery complete ===\n');

% Helper functions (scenario generation, checking, plotting) live in
% examples/private/ so this file stays a pure script, which publishes cleanly.
