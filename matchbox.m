function ch = matchbox(varargin)
% matchbox  Multi-observer capture-history matching. The front door.
%
% USAGE:
%   ch = matchbox(d1, d2, ..., dN, 'method', 'clustered', 'timeBuffer', tb)
%   ch = matchbox(d1, d2, ..., dN, 'method', 'gridded',   'gridStep', g)
%   ch = matchbox(d1, d2, ..., dN, 'method', 'pairwise',  'timeBuffer', tb)
%
% Each input d1..dN is one observer's detection table with columns
% t0, tEnd, fLow, fHigh (times in days). Returns one row per event, with
% detect_observerK flags and every observer's columns suffixed _observerK.
%
% METHODS
%   'clustered' (default)  Temporal single-linkage clustering. Best when
%                          calls are well separated relative to cross-observer
%                          timing jitter (Z-calls, D-calls, sparse bouts).
%                          Tuning parameter: 'timeBuffer' (default 0).
%   'gridded'              Fixed reference grid. Best when calls are
%                          close-spaced and one-event-per-call breaks down
%                          (fin 20/40 Hz pulse trains, choruses).
%                          Tuning parameter: 'gridStep' (required).
%   'pairwise'             Matches each observer against a growing
%                          aggregate, on time AND frequency overlap. Order
%                          dependent (see help multiCaptureHistoryPairwise).
%                          Use for reproducing pre-2026 results, or where
%                          frequency-gated matching is specifically wanted;
%                          prefer clustered/gridded for new work otherwise.
%                          Tuning parameter: 'timeBuffer' (default 0).
%
% SHARED OPTIONAL ARGUMENTS (forwarded to whichever method is chosen)
%   'splitRule'  'overlap' (default) or 'snr'
%   'verbose'    true (default) or false
%
% Method-specific parameters are forwarded to the chosen implementation,
% whose own parser validates them. Passing a parameter that belongs to a
% different method (for example 'gridStep' with 'method','clustered') is an
% error rather than a silent no-op.
%
% See also multiCaptureHistoryClustered, multiCaptureHistoryGridded,
% multiCaptureHistoryPairwise.
%
% B. Miller, AAD, 2026

% Separate leading table arguments from trailing name-value pairs.
nObs = 0;
while nObs < numel(varargin) && istable(varargin{nObs+1})
    nObs = nObs + 1;
end
tables = varargin(1:nObs);
nv     = varargin(nObs+1:end);

if nObs < 2
    error('matchbox:tooFewTables', 'Provide at least 2 detection tables.');
end

% Pull out 'method' (default 'clustered'); forward everything else unchanged
% to the chosen implementation, so its parser validates its own parameters.
method = 'clustered';
keep   = true(1, numel(nv));
for i = 1:2:numel(nv)-1
    if strcmpi(nv{i}, 'method')
        method       = lower(string(nv{i+1}));
        keep(i:i+1)  = false;
    end
end
fwd = nv(keep);

switch method
    case "clustered"
        ch = multiCaptureHistoryClustered(tables{:}, fwd{:});
    case "gridded"
        ch = multiCaptureHistoryGridded(tables{:}, fwd{:});
    case "pairwise"
        ch = multiCaptureHistoryPairwise(tables{:}, fwd{:});
    otherwise
        error('matchbox:unknownMethod', ...
              'Unknown method "%s". Use "clustered", "gridded", or "pairwise".', method);
end
end
