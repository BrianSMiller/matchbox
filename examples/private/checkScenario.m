function res = checkScenario(ch, truth)
% CHECKSCENARIO  Grade a recovered capture history against known truth.
%   Rebuilds the detection matrix from the recovered events and compares it
%   to truth.D. Merged events are left out of that reconstruction, because a
%   merged event conflates two calls and its detections cannot be attributed
%   to one of them; they are counted on their own as nMerged instead. A rung
%   passes when the matrix matches, no events are merged, and every detected
%   call was recovered as its own event.
ev = computeEventIds(ch, truth.nObs);

Drec = false(truth.nCalls, truth.nObs);
for e = 1:ev.nEvents
    if isnan(ev.realId(e)) || ev.merged(e), continue; end   % skip FP and merged
    k = ev.realId(e);
    for o = 1:truth.nObs
        Drec(k,o) = logical(ch.(sprintf('detect_observer%d', o))(e));
    end
end

det = truth.detectedCalls;              % compare only on calls someone saw
res.nEvents         = ev.nEvents;
res.nMerged         = sum(ev.merged);
res.nFPevents       = sum(ev.isFP);
res.matrixMatch     = isequal(Drec(det,:), truth.D(det,:));
res.nCallsRecovered = numel(unique(ev.realId(~isnan(ev.realId) & ~ev.merged)));
res.nCallsExpected  = numel(det);
res.nCallsTrue      = truth.nCalls;              % all true calls, detected or not
res.nUnobserved     = truth.nCalls - numel(det); % calls no observer detected

% Capture frequency: of the clean recovered events, how many were seen by
% exactly j observers. This is the observed part of the capture-recapture
% data; the j = 0 class (missed by all) is nUnobserved above and is what the
% analysis estimates rather than observes.
detCols    = arrayfun(@(o) sprintf('detect_observer%d', o), 1:truth.nObs, 'uni', 0);
realEvents = ~isnan(ev.realId) & ~ev.merged;
nSeen      = sum(ch{realEvents, detCols} == 1, 2);
res.captureFreq = accumarray(nSeen, 1, [truth.nObs 1])';   % counts for j = 1..nObs

res.pass = res.matrixMatch && res.nMerged == 0 && ...
           res.nCallsRecovered == res.nCallsExpected;
end
