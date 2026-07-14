function cht = resolveObserverColumns(cht, columnNames, varargin)
% resolveObserverColumns  Fill top-level column(s) on a matchbox CHT by
% resolving each event's value from whichever observer actually detected
% it, in priority order, rather than assuming a specific observer (e.g.
% observer 1) always contributed.
%
% matchbox's own envelope construction only builds t0/tEnd/fLow/fHigh at
% the top level; every other column exists only as <col>_observerK,
% NaN/missing where that observer didn't detect. For columns that are
% effectively deployment-level constants shared by every observer
% (soundFolder, channel, siteCode) rather than detection-specific
% measurements, downstream steps need ONE top-level value per event --
% but hardcoding a single observer's suffixed column silently produces
% missing values for every event that observer didn't detect (confirmed
% bug: Bp-Downsweep SNR was 100% Koogu-detected rows, 0 Maxi-only, because
% soundFolder/channel were pulled from observer1 unconditionally).
%
%   cht = resolveObserverColumns(cht, {'soundFolder','channel'})
%   cht = resolveObserverColumns(cht, {'fLow','fHigh'}, 'priority', [2 1])
%
% Inputs
%   cht          - CHT table from matchbox(), with detect_observerK and
%                  <col>_observerK columns for K = 1..nObs
%   columnNames  - cellstr of base column name(s) to resolve
%
% Name-value args
%   priority     - observer index order to try, e.g. [2 1] tries observer
%                  2 first, falling back to observer 1 where observer 2
%                  didn't detect. Default: [1 2 ... nObs] (lowest index
%                  that detected each event wins).
%
% Errors loudly if any event has no detecting observer for a requested
% column -- should be structurally impossible (every event has >=1
% detector by construction) but checked rather than assumed.
%
% B. Miller, AAD, 2026

nObs = 0;
while any(strcmp(sprintf('detect_observer%d', nObs+1), cht.Properties.VariableNames))
    nObs = nObs + 1;
end
if nObs == 0
    error('resolveObserverColumns:noObservers', ...
        'No detect_observerK columns found -- is this a matchbox CHT?');
end

p = inputParser;
addParameter(p, 'priority', 1:nObs, @(x) isnumeric(x) && isequal(sort(x(:)'), 1:nObs));
parse(p, varargin{:});
priority = p.Results.priority;

nEvents = height(cht);

for c = 1:numel(columnNames)
    colName  = columnNames{c};
    firstCol = sprintf('%s_observer%d', colName, priority(1));
    if ~any(strcmp(firstCol, cht.Properties.VariableNames))
        error('resolveObserverColumns:missingColumn', ...
            'Column "%s" not found for observer %d.', colName, priority(1));
    end
    isNumericCol = isnumeric(cht.(firstCol)) || islogical(cht.(firstCol));

    if isNumericCol
        resolved = nan(nEvents, 1);
    else
        resolved = repmat({''}, nEvents, 1);
    end
    unresolved = true(nEvents, 1);

    for k = priority
        detCol = sprintf('detect_observer%d', k);
        srcCol = sprintf('%s_observer%d', colName, k);
        if ~any(strcmp(srcCol, cht.Properties.VariableNames))
            continue;
        end
        fillRows = unresolved & cht.(detCol);
        resolved(fillRows) = cht.(srcCol)(fillRows);
        unresolved(fillRows) = false;
    end

    if any(unresolved)
        error('resolveObserverColumns:noDetectingObserver', ...
            '%d event(s) have no detecting observer for column "%s" -- should be impossible.', ...
            sum(unresolved), colName);
    end

    cht.(colName) = resolved;
end
end