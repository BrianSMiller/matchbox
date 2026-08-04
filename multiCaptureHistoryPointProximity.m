function ch = multiCaptureHistoryPointProximity(varargin)
% multiCaptureHistoryPointProximity  Build a multi-observer capture history
% table by clustering on a single reference point per detection, not
% interval overlap.
%
% USAGE:
%   ch = multiCaptureHistoryPointProximity(d1, d2)
%   ch = multiCaptureHistoryPointProximity(d1, d2, ..., dN)
%   ch = multiCaptureHistoryPointProximity(d1, ..., dN, 'timeBuffer', tb)
%   ch = multiCaptureHistoryPointProximity(d1, ..., dN, 'refCol', 'center')
%
% Each input d1..dN is one observer's detection table, with at least the
% columns t0, tEnd, fLow, fHigh (start time, end time, low/high frequency).
% t0 and tEnd are in days (datenum convention), matching the other
% matchers.
%
% METHOD
%   Where multiCaptureHistoryClustered links two detections when their
%   INTERVALS overlap (within timeBuffer) -- a test that uses both
%   endpoints of both detections, i.e. two points each -- this method
%   links two detections when a single reference POINT from each is
%   within timeBuffer of the other. One point per detection, not two: no
%   interval overlap test, no frequency test. This is the point-based,
%   frequency-blind matching philosophy behind Schall & Parcerisas
%   (2022)'s stated criterion for evaluating fin whale 20 Hz pulse
%   detectors -- but NOT a literal reproduction of it. Their algorithm is
%   deliberately many-to-many (one detection can satisfy several
%   annotations at once, tracked as two independently-defined coverage
%   counts, not resolved into a single event set) and asymmetric
%   (annotation start time vs detection center time playing different
%   roles). matchbox's contract requires one row per event with a unique
%   key, which forces a many-to-many algorithm through a collapse rule
%   (splitRule) that their algorithm doesn't have and doesn't need. If you
%   need to reproduce their published numbers exactly, use
%   scoreAgainstAnnotations.m / matchByTimeProximity.m directly, not this
%   function -- that comparison is why this function exists as a
%   deliberately different, matchbox-native method rather than a port.
%
%   All detections from all observers are pooled, each reduced to one
%   reference point (see 'refCol'), sorted by that point, and single-
%   linked: a new event opens whenever a point is more than timeBuffer
%   after the previous one in sorted order. Order independent, same as
%   multiCaptureHistoryClustered.
%
%   Within an event an observer may contribute more than one detection (a
%   splitter). These are collapsed to one row per observer per event using
%   splitRule. The result has exactly one row per event.
%
% OUTPUT
%   ch  table with one row per event and columns:
%         key                    event identifier (1..nEvents)
%         t0, tEnd, fLow, fHigh  event envelope (min start, max end,
%                                min fLow, max fHigh over contributors --
%                                the full interval span of every
%                                contributing detection, even though
%                                matching itself only used one point)
%         detect_observerK       logical, true if observer K detected event
%         <col>_observerK        every column of observer K's table,
%                                suffixed, NaN/missing where K missed
%
% OPTIONAL NAME-VALUE ARGUMENTS
%   'timeBuffer' - Distance in days tolerated between reference points
%                  before a new event is opened. Default 0 (points must be
%                  identical). Schall & Parcerisas's own tolerance is
%                  1.5 seconds, i.e. 1.5/86400.
%   'refCol'     - Which point to use per detection. Either one value
%                  applied to every observer, or a cell array with one
%                  entry per observer (in input order) for per-observer
%                  overrides. Each value is one of:
%                    't0'     (default) detection start time.
%                    'tEnd'   detection end time.
%                    'center' (t0+tEnd)/2 -- computed, not a real column.
%                    any other string -- an actual column name in that
%                             observer's table (e.g. 'DateTime'), read
%                             directly. datetime-typed columns are
%                             converted to datenum internally; anything
%                             else is assumed already in datenum days,
%                             matching t0/tEnd.
%                  Default 't0' for every observer: symmetric, no
%                  observer privileged as "the one with the true point",
%                  appropriate for comparing several detectors on equal
%                  footing. Override per-observer only if you have a
%                  specific reason one observer's meaningful point isn't
%                  its start time.
%   'splitRule'  - How to collapse multiple detections from one observer
%                  in one event:
%                    'overlap' (default) keep the detection whose
%                              reference point is closest to the event's
%                              mean reference point. Named 'overlap' for
%                              interface consistency with the other three
%                              methods, but reinterpreted here as
%                              closeness rather than interval overlap --
%                              there is no interval overlap concept in
%                              point matching.
%                    'snr'     keep the detection with the highest snr
%                              (requires an 'snr' column; falls back to
%                              'overlap' with a warning if absent).
%   'verbose'    - Print a short summary (default true).
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
    error('multiCaptureHistoryPointProximity:tooFewTables', ...
          'Provide at least 2 detection tables.');
end

p = inputParser;
addParameter(p, 'timeBuffer', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'refCol', 't0', @(x) ischar(x) || isstring(x) || iscell(x));
addParameter(p, 'splitRule', 'overlap', ...
             @(x) any(strcmpi(x, {'overlap','snr'})));
addParameter(p, 'verbose', true, @(x) islogical(x) || isnumeric(x));
parse(p, nv{:});
timeBuffer = p.Results.timeBuffer;
refColSpec = p.Results.refCol;
splitRule  = lower(p.Results.splitRule);
verbose    = logical(p.Results.verbose);

required = {'t0','tEnd','fLow','fHigh'};

% ---- pool all detections, tagged with observer and source row ----------
poolT0 = []; poolTEnd = []; poolLow = []; poolHigh = []; poolPoint = [];
poolObs = []; poolRow = []; poolSnr = [];

for k = 1:nObs
    d = tables{k};
    missingCols = setdiff(required, d.Properties.VariableNames);
    if ~isempty(missingCols)
        error('multiCaptureHistoryPointProximity:missingColumns', ...
              'Observer %d is missing column(s): %s', ...
              k, strjoin(missingCols, ', '));
    end
    n = height(d);
    point = localResolvePoint(d, refColSpec, k);
    poolT0    = [poolT0;    d.t0];
    poolTEnd  = [poolTEnd;  d.tEnd];
    poolLow   = [poolLow;   d.fLow];
    poolHigh  = [poolHigh;  d.fHigh];
    poolPoint = [poolPoint; point];
    poolObs   = [poolObs;   repmat(k, n, 1)];
    poolRow   = [poolRow;   (1:n)'];
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

% ---- sort by reference point, then single-link on point distance -------
[~, order] = sort(poolPoint);
poolT0    = poolT0(order);    poolTEnd = poolTEnd(order);
poolLow   = poolLow(order);   poolHigh = poolHigh(order);
poolPoint = poolPoint(order);
poolObs   = poolObs(order);   poolRow  = poolRow(order);
poolSnr   = poolSnr(order);

eventId = ones(nPool, 1);
for i = 2:nPool
    if poolPoint(i) - poolPoint(i-1) <= timeBuffer
        eventId(i) = eventId(i-1);
    else
        eventId(i) = eventId(i-1) + 1;
    end
end
nEvents = eventId(end);

% ---- event envelope (full interval span, one row per event) ------------
% Matching used only the reference point; the reported envelope is still
% the true known extent of the event, same contract as the other methods.
envT0   = accumarray(eventId, poolT0,   [nEvents 1], @min);
envTEnd = accumarray(eventId, poolTEnd, [nEvents 1], @max);
envLow  = accumarray(eventId, poolLow,  [nEvents 1], @min);
envHigh = accumarray(eventId, poolHigh, [nEvents 1], @max);
envPointMean = accumarray(eventId, poolPoint, [nEvents 1], @mean);

ch = table((1:nEvents)', envT0, envTEnd, envLow, envHigh, ...
           'VariableNames', {'key','t0','tEnd','fLow','fHigh'});

% ---- attach each observer, collapsing splitters -------------------------
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
            otherwise  % 'overlap' -- reinterpreted as closeness, see help
                vals = -abs(poolPoint(sel(rows)) - envPointMean(uEv(m)));
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

% ---- report ---------------------------------------------------------------
if verbose
    fprintf('multiCaptureHistoryPointProximity: %d pooled detections -> %d events\n', ...
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
function point = localResolvePoint(d, refColSpec, k)
% Resolve observer k's reference-point column spec into a numeric datenum
% vector. refColSpec is either one value for all observers, or a cell
% array with one entry per observer.
if iscell(refColSpec)
    if numel(refColSpec) < k
        error('multiCaptureHistoryPointProximity:refColSize', ...
            'refCol is a cell array but has fewer than %d entries (one per observer required).', k);
    end
    spec = char(refColSpec{k});
else
    spec = char(refColSpec);
end

switch spec
    case 't0'
        point = d.t0;
    case 'tEnd'
        point = d.tEnd;
    case 'center'
        point = (d.t0 + d.tEnd) / 2;
    otherwise
        if ~ismember(spec, d.Properties.VariableNames)
            error('multiCaptureHistoryPointProximity:unknownRefCol', ...
                'Observer %d has no column "%s". Available columns: %s', ...
                k, spec, strjoin(d.Properties.VariableNames, ', '));
        end
        col = d.(spec);
        if isdatetime(col)
            point = datenum(col); %#ok<DATNM>
        else
            point = double(col);
        end
end
end
