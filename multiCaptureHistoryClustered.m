function ch = multiCaptureHistoryClustered(varargin)
% multiCaptureHistoryClustered  Build a multi-observer capture history table
% by temporal clustering rather than pairwise matching.
%
% USAGE:
%   ch = multiCaptureHistoryClustered(d1, d2)
%   ch = multiCaptureHistoryClustered(d1, d2, ..., dN)
%   ch = multiCaptureHistoryClustered(d1, ..., dN, 'timeBuffer', tb)
%   ch = multiCaptureHistoryClustered(d1, ..., dN, 'splitRule', 'overlap')
%
% Each input d1..dN is one observer's detection table, with at least the
% columns t0, tEnd, fLow, fHigh (start time, end time, low/high frequency).
% t0 and tEnd are in days (datenum convention), matching captureHistoryTable.
%
% METHOD
%   All detections from all observers are pooled and sorted by start time.
%   A single forward pass groups detections into "events": a new event
%   opens whenever a detection starts more than timeBuffer after the running
%   end of the current event. This is single-linkage clustering in time. It
%   is order independent, needs no outer join over duplicate keys, and
%   collapses lumping and splitting: one observer's long detection bridges
%   another's two short ones into a single event.
%
%   Within an event an observer may contribute more than one detection (a
%   splitter). These are collapsed to one row per observer per event using
%   splitRule. The result has exactly one row per event.
%
% OUTPUT
%   ch  table with one row per event and columns:
%         key                    event identifier (1..nEvents)
%         t0, tEnd, fLow, fHigh  event envelope (min start, max end,
%                                min fLow, max fHigh over contributors)
%         detect_observerK       logical, true if observer K detected event
%         <col>_observerK        every column of observer K's table,
%                                suffixed, NaN/missing where K missed
%
% OPTIONAL NAME-VALUE ARGUMENTS
%   'timeBuffer' - Gap in days tolerated between detections before a new
%                  event is opened. Default 0 (detections must overlap or
%                  exactly abut). A few seconds (e.g. 5/86400) is sensible
%                  when observers disagree slightly on call timing.
%   'splitRule'  - How to collapse multiple detections from one observer in
%                  one event:
%                    'overlap' (default) keep the detection with the largest
%                              temporal overlap with the event envelope.
%                    'snr'     keep the detection with the highest snr
%                              (requires an 'snr' column; falls back to
%                              'overlap' with a warning if absent).
%   'verbose'    - Print a short summary (default true).
%
% NOTE Clustering uses time only. For a single call type this is sufficient
% and matches the temporal-overlap matching used previously. For mixed call
% types, filter each input to one classification and run per type, exactly
% as the two-observer workflow does.
%
% B. Miller, AAD, 2026

% ---- separate leading table args from trailing name-value pairs --------
nObs = 0;
while nObs < numel(varargin) && istable(varargin{nObs+1})
    nObs = nObs + 1;
end
tables = varargin(1:nObs);
nv     = varargin(nObs+1:end);

if nObs < 2
    error('multiCaptureHistoryClustered:tooFewTables', ...
          'Provide at least 2 detection tables.');
end

p = inputParser;
addParameter(p, 'timeBuffer', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'splitRule', 'overlap', ...
             @(x) any(strcmpi(x, {'overlap','snr'})));
addParameter(p, 'verbose', true, @(x) islogical(x) || isnumeric(x));
parse(p, nv{:});
timeBuffer = p.Results.timeBuffer;
splitRule  = lower(p.Results.splitRule);
verbose    = logical(p.Results.verbose);

required = {'t0','tEnd','fLow','fHigh'};

% ---- pool all detections, tagged with observer and source row ----------
poolT0 = []; poolTEnd = []; poolLow = []; poolHigh = [];
poolObs = []; poolRow = []; poolSnr = [];

for k = 1:nObs
    d = tables{k};
    missingCols = setdiff(required, d.Properties.VariableNames);
    if ~isempty(missingCols)
        error('multiCaptureHistoryClustered:missingColumns', ...
              'Observer %d is missing column(s): %s', ...
              k, strjoin(missingCols, ', '));
    end
    n = height(d);
    poolT0   = [poolT0;   d.t0];
    poolTEnd = [poolTEnd; d.tEnd];
    poolLow  = [poolLow;  d.fLow];
    poolHigh = [poolHigh; d.fHigh];
    poolObs  = [poolObs;  repmat(k, n, 1)];
    poolRow  = [poolRow;  (1:n)'];
    if ismember('snr', d.Properties.VariableNames)
        poolSnr = [poolSnr; d.snr];
    else
        poolSnr = [poolSnr; nan(n,1)];
    end
end
nPool = numel(poolT0);

if strcmp(splitRule, 'snr') && all(isnan(poolSnr))
    warning(['splitRule ''snr'' requested but no observer has an snr ' ...
             'column; falling back to ''overlap''.']);
    splitRule = 'overlap';
end

% ---- sort by start time, then cluster in a single forward pass ---------
[~, order] = sort(poolT0);
poolT0   = poolT0(order);   poolTEnd = poolTEnd(order);
poolLow  = poolLow(order);  poolHigh = poolHigh(order);
poolObs  = poolObs(order);  poolRow  = poolRow(order);
poolSnr  = poolSnr(order);

eventId    = ones(nPool, 1);
runningEnd = poolTEnd(1);
for i = 2:nPool
    if poolT0(i) <= runningEnd + timeBuffer
        eventId(i) = eventId(i-1);
        runningEnd = max(runningEnd, poolTEnd(i));
    else
        eventId(i) = eventId(i-1) + 1;
        runningEnd = poolTEnd(i);
    end
end
nEvents = eventId(end);

% ---- event envelope (one row per event) --------------------------------
envT0   = accumarray(eventId, poolT0,   [nEvents 1], @min);
envTEnd = accumarray(eventId, poolTEnd, [nEvents 1], @max);
envLow  = accumarray(eventId, poolLow,  [nEvents 1], @min);
envHigh = accumarray(eventId, poolHigh, [nEvents 1], @max);

ch = table((1:nEvents)', envT0, envTEnd, envLow, envHigh, ...
           'VariableNames', {'key','t0','tEnd','fLow','fHigh'});

% ---- attach each observer, collapsing splitters ------------------------
nSplitCollapsed = 0;
for k = 1:nObs
    sel = find(poolObs == k);
    if isempty(sel)
        ch.(sprintf('detect_observer%d', k)) = false(nEvents, 1);
        continue;
    end
    ev = eventId(sel);

    % choose one detection per event for this observer
    keep = true(numel(sel), 1);
    [uEv, ~, ic] = unique(ev);
    for m = 1:numel(uEv)
        rows = find(ic == m);
        if numel(rows) == 1, continue; end
        nSplitCollapsed = nSplitCollapsed + 1;
        switch splitRule
            case 'snr'
                vals = poolSnr(sel(rows));
            otherwise  % 'overlap'
                vals = localOverlap(poolT0(sel(rows)), poolTEnd(sel(rows)), ...
                                    envT0(uEv(m)), envTEnd(uEv(m)));
        end
        [~, best] = max(vals);
        drop = rows; drop(best) = [];
        keep(drop) = false;
    end

    selKeep = sel(keep);
    evKeep  = eventId(selKeep);
    srcKeep = poolRow(selKeep);

    % build this observer's subtable, suffixed, with key = eventId
    sub = tables{k}(srcKeep, :);
    sub.Properties.VariableNames = ...
        strcat(sub.Properties.VariableNames, sprintf('_observer%d', k));
    sub.key = evKeep;
    sub.(sprintf('detect_observer%d', k)) = true(height(sub), 1);

    % keys are unique on both sides, so outerjoin cannot multiply rows
    before = height(ch);
    ch = outerjoin(ch, sub, 'Keys', {'key','key'}, 'MergeKeys', true);
    assert(height(ch) == before, ...
        'Row count changed when adding observer %d. Duplicate keys.', k);

    dc = sprintf('detect_observer%d', k);
    ch.(dc)(isnan(ch.(dc))) = 0;
    ch.(dc) = logical(ch.(dc));
end

% ---- report ------------------------------------------------------------
if verbose
    fprintf('multiCaptureHistoryClustered: %d pooled detections -> %d events\n', ...
            nPool, nEvents);
    for k = 1:nObs
        dc = sprintf('detect_observer%d', k);
        fprintf('  observer %d: %d pooled, %d events detected\n', ...
                k, sum(poolObs==k), sum(ch.(dc)));
    end
    fprintf('  observer-events with a collapsed splitter: %d\n', nSplitCollapsed);
end

end

% -------------------------------------------------------------------------
function ov = localOverlap(t0, tEnd, envT0, envTEnd)
% Temporal overlap (days) of each [t0,tEnd] with the event envelope.
ov = max(0, min(tEnd, envTEnd) - max(t0, envT0));
end
