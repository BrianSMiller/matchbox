function pr = scoreDetections(ch, groundTruthObserver, detectorObserver, varargin)
% scoreDetections  Precision/recall for one detector against one ground
% truth, from an already-built matchbox capture history table.
%
% USAGE
%   pr = scoreDetections(ch, groundTruthObserver, detectorObserver)
%   pr = scoreDetections(ch, groundTruthObserver, detectorObserver, 'numAbsent', n)
%
% ch is a capture history table built by matchbox(...) -- any method
% (clustered, gridded, or pairwise) -- with the usual key/detect_observerK
% contract. Matching is matchbox's job, not this function's: build ch
% first, then score it. groundTruthObserver and detectorObserver each
% select a detect_observerK column, as either the numeric observer index
% (1, 2, ...) matching matchbox's column-naming order, or the column name
% itself ('observer1' or 'detect_observer1', either works).
%
% Ground truth is the caller's choice, not hardcoded to observer 1: pass
% whichever observer represents ground truth for this comparison. Both
% arguments select from the same ch, so scoring analyst-vs-analyst or
% detector-vs-detector agreement works the same way as detector-vs-truth.
%
% Because matchbox guarantees one row per event for any of its three
% methods (no duplicate keys), this is a plain 2x2 confusion matrix -- no
% correction for duplicate-key artefacts is needed here, unlike the
% pre-2026 annotatedLibrary scoreDetections.m, which subtracted a
% duplicateMatches count to compensate for the legacy pairwise builder's
% row-multiplication bug (see multiCaptureHistoryPairwise.m). That bug no
% longer exists. This function asserts ch has unique keys and errors
% loudly if it doesn't, rather than silently correcting for it -- a
% duplicate key now means something built ch outside matchbox, or a new
% matchbox bug, either of which is worth knowing about rather than
% papering over again.
%
% OUTPUT pr, a 1-row table:
%   truePositive, falsePositive, falseNegative, numGroundTrue
%   precision, recall
%   trueNegative, falseAlarmRate   (only present if 'numAbsent' given)
%
% OPTIONAL NAME-VALUE ARGUMENTS
%   'numAbsent' - Total number of true-absence opportunities (e.g. total
%                 review windows minus numGroundTrue), needed only for
%                 falseAlarmRate/trueNegative. Estimating this is
%                 dataset-specific (effort duration, window size, call
%                 duration, etc.) and out of scope for this function --
%                 pass it in if you have it. Default: NaN, which omits
%                 trueNegative/falseAlarmRate from the output rather than
%                 computing a meaningless value against an unknown
%                 denominator.
%
% B. Miller, AAD, 2026

p = inputParser;
addParameter(p, 'numAbsent', NaN, @(x) isnumeric(x) && isscalar(x));
parse(p, varargin{:});
numAbsent = p.Results.numAbsent;

gtCol  = localResolveDetectColumn(ch, groundTruthObserver);
detCol = localResolveDetectColumn(ch, detectorObserver);

assert(numel(unique(ch.key)) == height(ch), ...
    'scoreDetections:duplicateKeys', ...
    ['ch has duplicate keys. scoreDetections assumes the matchbox ' ...
     'contract (one row per event); this should not happen for any ' ...
     'matchbox method. Check what built ch -- if it wasn''t matchbox(...) ' ...
     'or one of multiCaptureHistoryClustered/Gridded/Pairwise directly, ' ...
     'that''s likely why.']);

groundTrue = ch.(gtCol);
detectTrue = ch.(detCol);

numGroundTrue = sum(groundTrue);
truePositive  = sum(groundTrue & detectTrue);
falsePositive = sum(detectTrue & ~groundTrue);
falseNegative = numGroundTrue - truePositive;

precision = truePositive / (truePositive + falsePositive);
recall    = truePositive / numGroundTrue;

pr = table(truePositive, falsePositive, falseNegative, numGroundTrue, ...
           precision, recall);

if ~isnan(numAbsent)
    pr.trueNegative   = numAbsent - falsePositive;
    pr.falseAlarmRate = falsePositive / numAbsent;
end

end

% -------------------------------------------------------------------------
function col = localResolveDetectColumn(ch, observer)
if isnumeric(observer)
    col = sprintf('detect_observer%d', observer);
else
    col = char(observer);
    if ~startsWith(col, 'detect_')
        col = ['detect_' col];
    end
end
if ~ismember(col, ch.Properties.VariableNames)
    detectCols = ch.Properties.VariableNames( ...
        startsWith(ch.Properties.VariableNames, 'detect_'));
    error('scoreDetections:unknownObserver', ...
        'No column "%s" in ch. Available detect columns: %s', ...
        col, strjoin(detectCols, ', '));
end
end
