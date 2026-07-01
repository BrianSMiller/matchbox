function ch = multiCaptureHistoryGridded(varargin)
% multiCaptureHistoryGridded  Build a multi-observer capture history table by
% assigning detections to a fixed reference grid in time.
%
% USAGE:
%   ch = multiCaptureHistoryGridded(d1, d2, ..., dN, 'gridStep', g)
%   ch = multiCaptureHistoryGridded(d1, ..., dN, 'gridStep', g, 'splitRule', 'overlap')
%
% Each input d1..dN is one observer's detection table, with at least the
% columns t0, tEnd, fLow, fHigh (start time, end time, low/high frequency).
% t0 and tEnd are in days (datenum convention), matching the other matchers.
%
% METHOD
%   Time is divided into fixed bins of width gridStep, anchored to an
%   absolute grid (bin index = floor(midpoint / gridStep)). Each detection is
%   assigned to the bin containing its midpoint. Every occupied bin becomes
%   one event, and each observer is scored present or absent in that bin. The
%   result is one row per occupied bin.
%
%   This is the tool for the regime where clustering fails: calls so close
%   together that "one event = one call" is no longer well posed (fin 20/40
%   Hz pulse trains, choruses of several animals). The sampling unit becomes
%   the bin, not the call. The grid is anchored to absolute time, so the
%   result is independent of observer order and reproducible across runs.
%
%   Where an observer has more than one detection in a bin, they are
%   collapsed to one row using splitRule.
%
% OUTPUT
%   ch  table with one row per occupied bin and columns:
%         key                    event identifier (1..nEvents)
%         binStart               grid cell start time (bin index * gridStep)
%         t0, tEnd, fLow, fHigh  envelope of the detections in the bin
%         detect_observerK       logical, true if observer K detected in bin
%         <col>_observerK        every column of observer K's table,
%                                suffixed, NaN/missing where K was absent
%
% REQUIRED NAME-VALUE ARGUMENT
%   'gridStep'   - Bin width in the same units as t0 (days in the real
%                  pipeline). This is a scientific choice, like bin width in
%                  an occupancy analysis: wide enough that same-call timing
%                  disagreement stays within a bin, narrow enough that
%                  distinct calls usually fall in different bins. No default;
%                  choose per call type.
%
% OPTIONAL NAME-VALUE ARGUMENTS
%   'splitRule'  - How to collapse multiple detections from one observer in
%                  one bin:
%                    'overlap' (default) keep the detection with the largest
%                              temporal overlap with the bin cell.
%                    'snr'     keep the detection with the highest snr
%                              (requires an 'snr' column; falls back to
%                              'overlap' with a warning if absent).
%   'verbose'    - Print a short summary (default true).
%
% NOTE Assignment uses time only, so run separately per call type. A grid
% has a known cost at bin boundaries: a call whose observers straddle a
% boundary is split across two bins. Choose gridStep well above the timing
% disagreement to keep this rare. For well-separated calls prefer
% multiCaptureHistoryClustered, which has no boundary artefact.
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
    error('multiCaptureHistoryGridded:tooFewTables', ...
          'Provide at least 2 detection tables.');
end

p = inputParser;
addParameter(p, 'gridStep', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'splitRule', 'overlap', ...
             @(x) any(strcmpi(x, {'overlap','snr'})));
addParameter(p, 'verbose', true, @(x) islogical(x) || isnumeric(x));
parse(p, nv{:});
gridStep  = p.Results.gridStep;
splitRule = lower(p.Results.splitRule);
verbose   = logical(p.Results.verbose);

if isempty(gridStep)
    error('multiCaptureHistoryGridded:gridStepRequired', ...
          ['gridStep is required. Choose a bin width for this call type ' ...
           '(same units as t0), e.g. 60/86400 for one-minute bins.']);
end

required = {'t0','tEnd','fLow','fHigh'};

% ---- pool all detections, tagged with observer and source row ----------
poolT0 = []; poolTEnd = []; poolLow = []; poolHigh = [];
poolObs = []; poolRow = []; poolSnr = [];

for k = 1:nObs
    d = tables{k};
    missingCols = setdiff(required, d.Properties.VariableNames);
    if ~isempty(missingCols)
        error('multiCaptureHistoryGridded:missingColumns', ...
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

% ---- assign each detection to the grid bin containing its midpoint ------
midpoint = (poolT0 + poolTEnd) / 2;
binIdx   = floor(midpoint / gridStep);

% Map occupied bins to dense event ids 1..nEvents.
[uBins, ~, eventId] = unique(binIdx);
nEvents  = numel(uBins);
binStart = uBins * gridStep;          % grid cell start per event

% ---- event envelope (one row per occupied bin) -------------------------
envT0   = accumarray(eventId, poolT0,   [nEvents 1], @min);
envTEnd = accumarray(eventId, poolTEnd, [nEvents 1], @max);
envLow  = accumarray(eventId, poolLow,  [nEvents 1], @min);
envHigh = accumarray(eventId, poolHigh, [nEvents 1], @max);

ch = table((1:nEvents)', binStart, envT0, envTEnd, envLow, envHigh, ...
           'VariableNames', {'key','binStart','t0','tEnd','fLow','fHigh'});

% ---- attach each observer, collapsing multiples within a bin -----------
nBinCollapsed = 0;
for k = 1:nObs
    sel = find(poolObs == k);
    if isempty(sel)
        ch.(sprintf('detect_observer%d', k)) = false(nEvents, 1);
        continue;
    end
    ev = eventId(sel);

    % choose one detection per bin for this observer
    keep = true(numel(sel), 1);
    [uEv, ~, ic] = unique(ev);
    for m = 1:numel(uEv)
        rows = find(ic == m);
        if numel(rows) == 1, continue; end
        nBinCollapsed = nBinCollapsed + 1;
        switch splitRule
            case 'snr'
                vals = poolSnr(sel(rows));
            otherwise  % 'overlap' with the bin cell
                bs   = binStart(uEv(m));
                vals = localOverlap(poolT0(sel(rows)), poolTEnd(sel(rows)), ...
                                    bs, bs + gridStep);
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
    fprintf('multiCaptureHistoryGridded: %d pooled detections -> %d events ', ...
            nPool, nEvents);
    fprintf('(gridStep = %g)\n', gridStep);
    for k = 1:nObs
        dc = sprintf('detect_observer%d', k);
        fprintf('  observer %d: %d pooled, %d bins detected\n', ...
                k, sum(poolObs==k), sum(ch.(dc)));
    end
    fprintf('  observer-bins with a collapsed multiple: %d\n', nBinCollapsed);
end

end

% -------------------------------------------------------------------------
function ov = localOverlap(t0, tEnd, aStart, aEnd)
% Temporal overlap (same units as t0) of each [t0,tEnd] with [aStart,aEnd].
ov = max(0, min(tEnd, aEnd) - max(t0, aStart));
end
