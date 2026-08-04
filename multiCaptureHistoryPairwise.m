function ch = multiCaptureHistoryPairwise(varargin)
% multiCaptureHistoryPairwise  Build a multi-observer capture history table
% by matching each observer, in turn, against a growing aggregate.
%
% USAGE:
%   ch = multiCaptureHistoryPairwise(d1, d2)
%   ch = multiCaptureHistoryPairwise(d1, d2, ..., dN)
%   ch = multiCaptureHistoryPairwise(d1, ..., dN, 'timeBuffer', tb)
%   ch = multiCaptureHistoryPairwise(d1, ..., dN, 'splitRule', 'snr')
%
% Each input d1..dN is one observer's detection table, with at least the
% columns t0, tEnd, fLow, fHigh (start time, end time, low/high frequency).
% t0 and tEnd are in days (datenum convention), matching the other matchers.
%
% Promoted out of legacy/multiCaptureHistoryPairwise.m and consolidated with
% the two-table primitive formerly in pairwiseCaptureHistory.m (now a local
% subfunction here, not a separate public entry point). Same input/output
% contract and the same shared options as multiCaptureHistoryClustered and
% multiCaptureHistoryGridded: 'timeBuffer', 'splitRule', 'verbose', a
% detect_observerK flag and <col>_observerK columns per observer, one row
% per event.
%
% METHOD
%   Observer 1 seeds the aggregate: every one of its detections is its own
%   event. Each subsequent observer's detections are matched against the
%   CURRENT aggregate envelope one at a time: a detection matches an
%   existing event if it overlaps that event's envelope in time (within
%   timeBuffer) AND in frequency, and among candidates the one with the
%   largest time-overlap*frequency-overlap product wins. Unmatched
%   detections open new events. This is what distinguishes pairwise from
%   clustered/gridded: those two match on time alone; pairwise requires a
%   frequency match too, which is a real difference in what counts as the
%   "same call", not an oversight.
%
%   Matching against a growing aggregate is inherently sequential, so this
%   method is order dependent: which events exist by the time observer K is
%   considered depends on which observers came before it, and an ambiguous
%   overlap (from timing jitter, splitting, or lumping) can be resolved
%   differently depending on what is already in the aggregate. This is a
%   structural property of the pairwise approach, not a bug fixed by this
%   file. Prefer multiCaptureHistoryClustered or multiCaptureHistoryGridded
%   for new work unless the frequency-gated matching criterion here is
%   specifically what you want, or you are reproducing pre-2026 results.
%
%   What IS fixed here relative to the pre-2026 code: an incoming
%   observer's detections that all best-match the SAME existing event are
%   now collapsed to one row using splitRule, instead of silently
%   duplicating that event's row in the output (the row-multiplication bug
%   in the original captureHistoryTable.m wrapper). The event's envelope
%   still incorporates every one of that observer's matched detections
%   (min t0, max tEnd, min fLow, max fHigh), same as clustered/gridded;
%   splitRule only decides which single detection's other columns become
%   that event's <col>_observerK representative.
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
%   'timeBuffer' - Gap in days tolerated, in addition to overlap, when
%                  screening candidate matches. Default 0.
%   'splitRule'  - How to collapse multiple detections from one observer
%                  matching the same existing event:
%                    'overlap' (default) keep the detection with the
%                              largest time-overlap*frequency-overlap
%                              product (the same value used to select the
%                              match in the first place).
%                    'snr'     keep the detection with the highest snr
%                              (requires an 'snr' column; falls back to
%                              'overlap' with a warning if no observer has
%                              one at all, and per-observer if that
%                              observer's table lacks it).
%   'verbose'    - Print a short summary per observer added (default true).
%
% NOTE Matching uses time and frequency, so unlike the other two matchers
% there is no need to pre-filter by call type for the match criterion
% itself -- but mixed call types in one table will still produce
% nonsensical frequency-overlap comparisons, so filter to one
% classification per call as the other two matchers require.
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
    error('multiCaptureHistoryPairwise:tooFewTables', ...
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
for k = 1:nObs
    missingCols = setdiff(required, tables{k}.Properties.VariableNames);
    if ~isempty(missingCols)
        error('multiCaptureHistoryPairwise:missingColumns', ...
              'Observer %d is missing column(s): %s', ...
              k, strjoin(missingCols, ', '));
    end
end

hasAnySnr = any(cellfun(@(d) ismember('snr', d.Properties.VariableNames) ...
                         && any(~isnan(d.snr)), tables));
if strcmp(splitRule, 'snr') && ~hasAnySnr
    warning(['splitRule ''snr'' requested but no observer has an snr ' ...
             'column; falling back to ''overlap''.']);
    splitRule = 'overlap';
end

% ---- seed the aggregate from observer 1 --------------------------------
d1 = tables{1};
n1 = height(d1);
ch = table((1:n1)', d1.t0, d1.tEnd, d1.fLow, d1.fHigh, ...
           'VariableNames', {'key','t0','tEnd','fLow','fHigh'});
sub1 = d1;
sub1.Properties.VariableNames = strcat(sub1.Properties.VariableNames, '_observer1');
sub1.key = (1:n1)';
sub1.detect_observer1 = true(n1, 1);
ch = outerjoin(ch, sub1, 'Keys', {'key','key'}, 'MergeKeys', true);

if verbose
    fprintf('multiCaptureHistoryPairwise: observer 1 seeds %d events\n', n1);
end

% ---- match each subsequent observer against the current aggregate ------
for k = 2:nObs
    d = tables{k};
    nRows = height(d);

    % snapshot the aggregate envelope as it stands before this observer
    envKey  = ch.key;
    envT0   = ch.t0;
    envTEnd = ch.tEnd;
    envLow  = ch.fLow;
    envHigh = ch.fHigh;

    matchedKey = nan(nRows, 1);
    matchedVal = nan(nRows, 1);

    for j = 1:nRows
        s1 = d.t0(j); e1 = d.tEnd(j); l1 = d.fLow(j); u1 = d.fHigh(j);
        overlapIx = find(doTimespansOverlap(s1, e1, envT0, envTEnd, timeBuffer));
        overlapAmount = zeros(size(overlapIx));
        for ii = 1:numel(overlapIx)
            i = overlapIx(ii);
            tOv = timespanOverlap(s1, e1, envT0(i), envTEnd(i)) * 86400;
            if tOv > 0
                fOv = timespanOverlap(l1, u1, envLow(i), envHigh(i));
                overlapAmount(ii) = tOv * fOv;
            end
        end
        if any(overlapAmount > 0)
            [ov, best]        = max(overlapAmount);
            matchedKey(j)     = envKey(overlapIx(best));
            matchedVal(j)     = ov;
        end
    end

    matchedRows = find(~isnan(matchedKey));
    newRows     = find(isnan(matchedKey));
    nCollapsed  = 0;

    % ---- update envelope for every matched key (all contributors) ------
    if ~isempty(matchedRows)
        [uK, ~, ic] = unique(matchedKey(matchedRows));
        [tf, rowIdx] = ismember(uK, ch.key); %#ok<ASGLU>
        for m = 1:numel(uK)
            grp = matchedRows(ic == m);
            r   = rowIdx(m);
            ch.t0(r)    = min(ch.t0(r),    min(d.t0(grp)));
            ch.tEnd(r)  = max(ch.tEnd(r),  max(d.tEnd(grp)));
            ch.fLow(r)  = min(ch.fLow(r),  min(d.fLow(grp)));
            ch.fHigh(r) = max(ch.fHigh(r), max(d.fHigh(grp)));
        end
    end

    % ---- collapse duplicate matches to a single representative row -----
    winnerRows = false(numel(matchedRows), 1);
    if ~isempty(matchedRows)
        [uK, ~, ic] = unique(matchedKey(matchedRows));
        for m = 1:numel(uK)
            grpIx = find(ic == m);          % index into matchedRows
            grp   = matchedRows(grpIx);     % index into d
            if numel(grp) == 1
                winnerRows(grpIx) = true;
                continue;
            end
            nCollapsed = nCollapsed + 1;
            useSnr = strcmp(splitRule, 'snr') && ...
                     ismember('snr', d.Properties.VariableNames) && ...
                     any(~isnan(d.snr(grp)));
            if useSnr
                vals = d.snr(grp);
            else
                vals = matchedVal(grp);
            end
            [~, bestIx] = max(vals);
            winnerRows(grpIx(bestIx)) = true;
        end
    end
    winnerSrcRows = matchedRows(winnerRows);
    winnerKeys    = matchedKey(winnerSrcRows);

    % ---- assign new keys to unmatched rows (each its own event) --------
    nNew = numel(newRows);
    if nNew > 0
        startKey = max(ch.key) + 1;
        newKeys  = (startKey:(startKey + nNew - 1))';

        blank = repmat(ch(1, :), nNew, 1);
        blank = localBlankify(blank);
        blank.key    = newKeys;
        blank.t0     = d.t0(newRows);
        blank.tEnd   = d.tEnd(newRows);
        blank.fLow   = d.fLow(newRows);
        blank.fHigh  = d.fHigh(newRows);
        for j = 1:(k-1)
            blank.(sprintf('detect_observer%d', j)) = false(nNew, 1);
        end
        ch = [ch; blank]; %#ok<AGROW>
    else
        newKeys = zeros(0, 1);
    end

    % ---- attach observer k's own columns for both matched and new -----
    srcRows = [winnerSrcRows; newRows];
    keys    = [winnerKeys;    newKeys];

    sub = d(srcRows, :);
    sub.Properties.VariableNames = ...
        strcat(sub.Properties.VariableNames, sprintf('_observer%d', k));
    sub.key = keys;
    sub.(sprintf('detect_observer%d', k)) = true(height(sub), 1);

    before = height(ch);
    ch = outerjoin(ch, sub, 'Keys', {'key','key'}, 'MergeKeys', true);
    assert(height(ch) == before, ...
        'Row count changed when adding observer %d. Duplicate keys.', k);

    dc = sprintf('detect_observer%d', k);
    ch.(dc)(isnan(ch.(dc))) = 0;
    ch.(dc) = logical(ch.(dc));

    if verbose
        fprintf(['multiCaptureHistoryPairwise: observer %d (%d detections) ' ...
                 '-> %d matched existing events, %d new events'], ...
                k, nRows, numel(uniqueOrEmpty(winnerKeys)), nNew);
        if nCollapsed > 0
            fprintf(' (%d collapsed duplicate matches)', nCollapsed);
        end
        fprintf('\n');
    end
end

if verbose
    fprintf('multiCaptureHistoryPairwise: %d events total\n', height(ch));
    for k = 1:nObs
        dc = sprintf('detect_observer%d', k);
        fprintf('  observer %d: %d events detected\n', k, sum(ch.(dc)));
    end
    fprintf(['  NOTE: pairwise matching is order dependent (see help ' ...
             'multiCaptureHistoryPairwise). Prefer clustered/gridded for ' ...
             'new work unless frequency-gated matching is specifically ' ...
             'wanted.\n']);
end

end

% -------------------------------------------------------------------------
function t = localBlankify(t)
% Null out every column of a template row-table to a type-appropriate
% "missing" value, so newly opened events don't inherit stray values
% copied from the row the template was duplicated from.
vn = t.Properties.VariableNames;
for i = 1:numel(vn)
    col = t.(vn{i});
    if islogical(col)
        col(:) = false;
    elseif isnumeric(col)
        col(:) = NaN;
    elseif isdatetime(col)
        col(:) = NaT;
    elseif iscategorical(col)
        col(:) = categorical(missing);
    elseif isstring(col)
        col(:) = missing;
    elseif iscell(col)
        col(:) = {''};
    end
    t.(vn{i}) = col;
end
end

% -------------------------------------------------------------------------
function u = uniqueOrEmpty(x)
if isempty(x), u = []; else, u = unique(x); end
end
