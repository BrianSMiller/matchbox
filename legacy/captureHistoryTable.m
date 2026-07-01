function [cap] = captureHistoryTable(table1, table2, varargin )
% captureHistoryTable  LEGACY two-table capture-history primitive.
%
% ============================ WARNING ============================
% DEPRECATED. This is the pairwise primitive used by the legacy
% multiCaptureHistoryPairwise. It has a known bug in its candidate-overlap
% loop (the loop iterates once over a column vector rather than element by
% element, and the overlap accumulators are not cleared between rows), so
% matches involving more than one candidate are unreliable. Kept only for
% reproducibility. Prefer multiCaptureHistoryClustered.
% =================================================================
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
    overlap = 0;
    otherMatches = 0;

    for i = overlapIx; 1:height(table1);
        if isempty(i)
            continue;
        end
        s2 = start2(i); e2 = end2(i);

       tOverlap(i) = timespanOverlap(s1, e1, s2, e2); % Time overplap (days)

       fOverlap(i) = 0;
       if tOverlap(i) > 0
           tOverlap = tOverlap * 86400; % Convert to s;
           l1 = lowFreq1(j); u1 = hiFreq1(j);
           l2 = lowFreq2(i); u2 = hiFreq2(i);
           fOverlap(i) = timespanOverlap(l1,u1,l2,u2); % Frequency overlap (Hz)
           overlap(i) = tOverlap(i) .* fOverlap(i);
       end
    end

    ix = 1;
    if length(overlap) >= 1
        [overlap, ix] = max(overlap);
        otherMatches = find(ix==table2.key);
    end
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
