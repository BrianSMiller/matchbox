function pr = scoreDetectionsSweep(groundTruth, detections, thresholds, varargin)
% scoreDetectionsSweep  Precision/recall across a threshold sweep,
% matching each thresholded candidate set against ground truth via
% matchbox, then scoring with scoreDetections. One call replaces the
% bespoke per-detector sweep-and-score loops (sweepF20pThresholds,
% sweepKooguThreshold, and the inline loop in the old pamguard_scc
% benchmark script) with a single implementation.
%
% USAGE
%   pr = scoreDetectionsSweep(groundTruth, detections, thresholds, 'scoreCol', 'score')
%   pr = scoreDetectionsSweep(groundTruth, detectionsByThreshold, thresholds)
%
% `detections` takes one of two shapes, matching the two ways detectors in
% this repo produce a threshold sweep:
%
%   TABLE + 'scoreCol'   One detection table with a numeric score column
%                        (a DNN's probability, a test statistic, whatever
%                        the detector calls it). At each threshold,
%                        detections(detections.(scoreCol) >= threshold, :)
%                        is matched against groundTruth. Use this when the
%                        detector already outputs discrete candidate boxes
%                        each carrying their own score -- a straight
%                        column filter recovers the candidate set at any
%                        threshold, no detector-specific logic needed.
%
%   CELL ARRAY           One detection table per threshold already built
%                        (e.g. a SQL query re-run per correlation
%                        threshold). No filtering: detections{i} is
%                        matched against groundTruth for thresholds(i)
%                        directly. numel(detections) must equal
%                        numel(thresholds). Use this when going from
%                        "threshold value" to "candidate boxes" isn't a
%                        simple column filter -- for example, a detector
%                        whose test statistic requires windowing/merging
%                        into boxes fresh at each threshold. That
%                        conversion is the detector's own business and
%                        happens before calling this function; this
%                        function only matches and scores what it's
%                        given.
%
% Empty candidate tables (no detections at some threshold) are skipped,
% and that threshold is simply absent from pr, for both input shapes --
% no need to pre-filter before calling.
%
% groundTruth is always matchbox observer 1 and the candidate table is
% always observer 2 in each per-threshold match, since matchbox is called
% fresh with exactly these two tables every iteration -- but which table
% you pass as groundTruth is entirely your choice, made once, here.
%
% OPTIONAL NAME-VALUE ARGUMENTS
%   'scoreCol'   Column name in `detections` to threshold on. Required if
%                `detections` is a single table; ignored (with a warning
%                if supplied) if `detections` is a cell array.
%   'matchOpts'  Cell array forwarded to matchbox(groundTruth, candidate,
%                matchOpts{:}), e.g. {'method','clustered','timeBuffer',
%                5/86400}. Default {} (matchbox's own defaults: clustered,
%                timeBuffer 0).
%   'numAbsent'  Forwarded to scoreDetections (see there for what it's
%                for). Default NaN.
%
% OUTPUT pr, one row per threshold with a detection at it, sorted by
% threshold ascending. Columns: threshold, then whatever scoreDetections
% returns (truePositive, falsePositive, falseNegative, numGroundTrue,
% precision, recall, and trueNegative/falseAlarmRate if numAbsent given).
%
% B. Miller, AAD, 2026

p = inputParser;
addParameter(p, 'scoreCol', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'matchOpts', {}, @iscell);
addParameter(p, 'numAbsent', NaN, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
scoreCol  = char(p.Results.scoreCol);
matchOpts = p.Results.matchOpts;
numAbsent = p.Results.numAbsent;

thresholds = thresholds(:);
nThresh = numel(thresholds);

if istable(detections)
    if isempty(scoreCol)
        error('scoreDetectionsSweep:missingScoreCol', ...
            '''scoreCol'' is required when detections is a single table.');
    end
    if ~ismember(scoreCol, detections.Properties.VariableNames)
        error('scoreDetectionsSweep:unknownScoreCol', ...
            'No column "%s" in detections. Available columns: %s', ...
            scoreCol, strjoin(detections.Properties.VariableNames, ', '));
    end
    getCandidate = @(i) detections(detections.(scoreCol) >= thresholds(i), :);
elseif iscell(detections)
    if ~isempty(scoreCol)
        warning('scoreDetectionsSweep:scoreColIgnored', ...
            '''scoreCol'' is ignored when detections is a cell array.');
    end
    if numel(detections) ~= nThresh
        error('scoreDetectionsSweep:sizeMismatch', ...
            'numel(detections) (%d) must equal numel(thresholds) (%d).', ...
            numel(detections), nThresh);
    end
    getCandidate = @(i) detections{i};
else
    error('scoreDetectionsSweep:badDetections', ...
        ['detections must be a table (with ''scoreCol'') or a cell ' ...
         'array of tables, one per threshold.']);
end

rows = cell(nThresh, 1);
for i = 1:nThresh
    candidate = getCandidate(i);
    if isempty(candidate) || height(candidate) == 0
        rows{i} = table();
        continue;
    end
    ch  = matchbox(groundTruth, candidate, matchOpts{:});
    row = scoreDetections(ch, 1, 2, 'numAbsent', numAbsent);
    rows{i} = [table(thresholds(i), 'VariableNames', {'threshold'}), row];
end

keep = ~cellfun(@(r) isempty(r) || height(r) == 0, rows);
if ~any(keep)
    warning('scoreDetectionsSweep:noDetections', ...
        'No threshold produced any candidate detections. Returning an empty table.');
    pr = table();
    return;
end
pr = vertcat(rows{keep});
pr = sortrows(pr, 'threshold');

end
