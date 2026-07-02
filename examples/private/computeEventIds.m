function ev = computeEventIds(ch, nObs)
% COMPUTEEVENTIDS  Decode each recovered event's true-call content.
%   For every event, gather the trueCall id each observer contributed (via
%   the trueCall_observerK columns the matcher carried through). The set of
%   positive ids tells us what the event really is:
%       empty / all zero  -> a false-positive event
%       one positive id   -> a clean event (one real call)
%       several ids       -> a merge (two real calls in one event)
%   This is deliberately independent of observer labelling, so it survives
%   shuffling the input order.
n = height(ch);
V = nan(n, nObs);
for o = 1:nObs
    col = sprintf('trueCall_observer%d', o);
    if ismember(col, ch.Properties.VariableNames), V(:,o) = ch.(col); end
end
realId = nan(n,1); merged = false(n,1); isFP = false(n,1);
for e = 1:n
    ids = V(e,:); ids = ids(~isnan(ids)); pos = unique(ids(ids > 0));
    if isempty(pos), isFP(e) = true;               % nothing positive -> FP
    else, realId(e) = pos(1); merged(e) = numel(pos) > 1;  % >1 id -> merge
    end
end
ev.nEvents   = n;
ev.realId    = realId;        % the call id each event maps to (NaN if FP)
ev.merged    = merged;        % true where an event conflates >1 call
ev.isFP      = isFP;
ev.sortedIds = sort(realId(~isnan(realId)));   % label-independent signature
end
