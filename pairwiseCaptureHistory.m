function [cap] = pairwiseCaptureHistory(table1, table2, varargin)
% pairwiseCaptureHistory  Two-table capture-history primitive.
%
% Promoted from matchbox/legacy/captureHistoryTable.m -- two-detector
% setups are common enough (and match legacy behaviour) that this is a
% supported, first-class option, not a discouraged one. It is
% methodologically different from multiCaptureHistoryClustered/Gridded,
% not wrong: see multiCaptureHistoryPairwise.m for the known
% order-dependence caveat that comes with matching pairwise against a
% growing aggregate. That tradeoff is inherent to the pairwise approach
% and is NOT fixed by this file -- only a distinct loop/accumulator bug
% in the overlap computation below has been fixed (previously caused
% unreliable results whenever a detection had more than one candidate
% overlap -- see git history for captureHistoryTable.m for the original
% buggy version and full diagnosis).
%
% Create a Capture History Table, CAP, from two tables of detections,
% table1 & table2. Rows in the capture history table represent detections,
% and detection time-frequency bounds from the two tables are compared to
% determine if a detection from table2 overlaps with any from Table1.
%
% Detection tables must have columns t0, tEnd, fLow, fHigh (start time, end
% time, lower and upper frequency bound).
%
% Optional Name-Value Arguments:
%   'timeBuffer'  - Time buffer in days applied to both ends of each time
%                   interval before checking for overlap. Default: 0.

% Parse optional name-value arguments
p = inputParser;
addParameter(p, 'timeBuffer', 0);  % Time buffer in days (matches t0/tEnd units)
parse(p, varargin{:});
timeBuffer = p.Results.timeBuffer;

tic;
str='';
table1.detect = true(size(table1.t0));
table2.detect = true(size(table2.t0));
table2.overlap = nan(height(table2),1);

% In Matlab 2014a, accessing table cells by index is incredibly slow if
% done within a for loop, so we extract these columns into separate
% variables to speed things up.
start1 = table2.t0; end1 = table2.tEnd;
start2 = table1.t0; end2 = table1.tEnd;
lowFreq1 = table2.fLow; hiFreq1 = table2.fHigh;
lowFreq2 = table1.fLow; hiFreq2 = table1.fHigh;

table1.Properties.VariableNames = strcat(table1.Properties.VariableNames,'_table1');
table2.Properties.VariableNames = strcat(table2.Properties.VariableNames,'_table2');
table1.key = [1:height(table1)]';
table2.key = nan(height(table2),1);
k = height(table1);

for j = 1:height(table2)
    s1 = start1(j); e1 = end1(j);

    overlapIx = find(doTimespansOverlap(s1, e1, start2, end2, timeBuffer));

    % Explicit per-candidate loop with local scalars -- fixes two bugs in
    % the original: (1) `for i = overlapIx` iterated once over the WHOLE
    % column vector rather than once per candidate, so `if tOverlap(i)>0`
    % implicitly meant all() across candidates, wrongly skipping
    % frequency overlap for genuine matches whenever any co-candidate had
    % non-positive time overlap; (2) `tOverlap = tOverlap*86400` rescaled
    % the entire accumulator array with no reset between outer j
    % iterations, compounding across rows. Local scalars here can't have
    % either problem -- freshly computed and discarded every inner
    % iteration.
    overlapAmount = zeros(size(overlapIx));
    for ii = 1:numel(overlapIx)
        i = overlapIx(ii);
        s2 = start2(i); e2 = end2(i);

        tOv = timespanOverlap(s1, e1, s2, e2) * 86400; % days -> seconds
        if tOv > 0
            l1 = lowFreq1(j); u1 = hiFreq1(j);
            l2 = lowFreq2(i); u2 = hiFreq2(i);
            fOv = timespanOverlap(l1, u1, l2, u2); % Frequency overlap (Hz)
            overlapAmount(ii) = tOv * fOv;
        end
    end

    overlap = 0;
    ix = 1;
    if any(overlapAmount > 0)
        [overlap, bestIx] = max(overlapAmount);
        ix = overlapIx(bestIx);
    end
    otherMatches = find(ix==table2.key); %#ok<NASGU> % kept for parity with original; unused downstream there too
    table2.overlap(j) = overlap;

    if overlap > 0 % Match, so add this to an existing row
        table2.key(j) = ix;
    else % Add a new row to our capture history
        k = k+1;
        table2.key(j) = k;
    end
    if rem(j,500)==0 || j == height(table2)
        fprintf(repmat('\b',1,length(str)));
        str = sprintf('%g/%g rows from table2 compared with table 1 in %g s\n',...
                j, height(table2), toc);
        fprintf(str);
    end
end

% Merge the two tables into a single table using an outer-join.
cap = outerjoin(table1,table2,'keys',{'key','key'},'MergeKeys',true);

fprintf(['%g events\n',...
         '%g table1\n',...
         '%g table2\n',...
         '%g both\n',...
         '%g duplicate matches from table2 to table1\n'],...
        height(cap),...
        height(table1),...
        height(table2),...
        height(table1)+height(table2)-height(cap),...
        height(cap)-length(unique(cap.key)));
