function ch = multiCaptureHistoryPairwise(d1,d2,varargin)
% multiCaptureHistoryPairwise  LEGACY multi-observer capture-history builder.
%
% ============================ WARNING ============================
% DEPRECATED. Kept only to reproduce results produced before 2026.
% Do NOT use this for new work. Prefer multiCaptureHistoryClustered.
%
% Known problems:
%   * Order dependent. The result changes with the order the tables are
%     passed in, because detections are matched pairwise against a growing
%     aggregate rather than against a shared event pool. On real data this
%     changed per-observer detection counts by hundreds.
%   * Row multiplication. The underlying outerjoin over a non-unique key
%     duplicates rows whenever a detection matches more than one other, which
%     lumping and splitting routinely cause. Event counts come out inflated.
%   * Garbled column names beyond two observers. The suffix bookkeeping
%     produces names like key_observer12 for three or more observers.
%
% At best this is defensible for exactly TWO tables, and even then the
% pairwise primitive (legacy/captureHistoryTable.m) has a bug in its
% overlap loop. Treat any output with suspicion.
% =================================================================
%
% Make a capture history table from multiple detection tables, d1, d2, ...,
% dN, where each detection table is from a different (independent) observer.

warning('matchbox:deprecatedPairwise', ...
    ['multiCaptureHistoryPairwise is deprecated and order dependent. ' ...
     'Use multiCaptureHistoryClustered. Suppress with ' ...
     'warning(''off'',''matchbox:deprecatedPairwise'').']);

if nargin < 2
    error('Must include more than 1 detection table as input arguments')
end

names = append('_observer',string(1:nargin));
ch = captureHistoryTable(d1,d2);
% Replace variable names '_table1' with correct analyst number
ch.Properties.VariableNames = strrep(ch.Properties.VariableNames,...
    '_table1',names{1});
ch.Properties.VariableNames = strrep(ch.Properties.VariableNames,...
    '_table2',names{2});

ch.t0 = ch.t0_observer1;
ch.tEnd = ch.tEnd_observer1;
ch.fLow = ch.fLow_observer1;
ch.fHigh = ch.fHigh_observer1;

ix = isnan(ch.t0);
ch.t0(ix) = ch.t0_observer2(ix);
ch.tEnd(ix) = ch.tEnd_observer2(ix);
ch.fLow(ix) = ch.fLow_observer2(ix);
ch.fHigh(ix) = ch.fHigh_observer2(ix);

nameToChange = {'overlap_table1','t0_table1','tEnd_table1',...
    'fLow_table1','fHigh_table1','key_table1'};
for i = 1:length(varargin)
    ch = captureHistoryTable(ch,varargin{i});
    % So at this point the table names are a bit confusing. ch has a bunch
    % of unneccesary _table1 appended, so we need to get rid of that --
    % except for a few fields that were created above that are a
    % combination of observers 1:i. These special fields get
    % renamed from table1 to observer1:i. Finally, we replace _table2 with
    % observer 'i+1'.

    suffix_table1 = ['_observer' sprintf('%g',(1:i:i+1))];
    suffix_table2 = ['_observer' num2str(i+2)];
    newName = strrep(nameToChange,'_table1',suffix_table1 );
    ch = renamevars(ch,nameToChange,newName);
    ch.Properties.VariableNames = strrep(ch.Properties.VariableNames,...
        '_table1','');
    ch.Properties.VariableNames = strrep(ch.Properties.VariableNames,...
        '_table2',suffix_table2);

    ch.t0 = ch{:,['t0' suffix_table1]};
    ch.tEnd = ch{:,['tEnd' suffix_table1]};
    ch.fLow = ch{:,['fLow' suffix_table1]};
    ch.fHigh = ch{:,['fHigh' suffix_table1]};

    ix = isnan(ch.t0);
    ch.t0(ix) = ch{ix,['t0' suffix_table2]};
    ch.tEnd(ix) = ch{ix,['tEnd' suffix_table2]};
    ch.fLow(ix) = ch{ix,['fLow' suffix_table2]};
    ch.fHigh(ix) = ch{ix,['fHigh' suffix_table2]};
end
