function [tables, truth] = genScenario(p)
% GENSCENARIO  Build observer detection tables with known ground truth.
%   Lays down p.nCalls true calls along a timeline, decides which observer
%   detected which call, then turns each detected call into one or more
%   boxes with the requested jitter, splitting, lumping, and false
%   positives. Every box carries two hidden truth columns:
%       trueCall  the call it belongs to (0 for a false positive)
%       nCalls    how many true calls the box actually covers (2 if lumped)
%   These ride through the matcher so the checker can grade the result.
rng(p.seed);

% True call centre times. Draw gaps, but keep them at least minGap apart so
% that (in the separable regime) neighbouring calls do not overlap. In the
% chorus regime minGap is small on purpose so they can.
if isempty(p.minGap), minGap = p.callDur + 4*p.timeJitter + 5;
else,                 minGap = p.minGap;
end
gaps    = max(p.gapMean + p.gapJitter*randn(p.nCalls,1), minGap);
tCentre = cumsum(gaps);

% Detection design matrix D (nCalls-by-nObs): who detected what. Accept a
% ready-made logical matrix, a per-observer probability vector, or a single
% probability applied to all observers.
pd = p.pDetect;
if ~isscalar(pd) && isequal(size(pd), [p.nCalls p.nObs])
    D = logical(pd);
else
    if isscalar(pd), pd = repmat(pd, 1, p.nObs); end
    D = rand(p.nCalls, p.nObs) < pd;
end

% Expand scalar behaviour rates to one value per observer.
pSplit = p.pSplit; if isscalar(pSplit), pSplit = repmat(pSplit, 1, p.nObs); end
pLump  = p.pLump;  if isscalar(pLump),  pLump  = repmat(pLump,  1, p.nObs); end
nFP    = p.nFP;    if isscalar(nFP),    nFP    = repmat(nFP,    1, p.nObs); end
span   = [min(tCentre) - p.gapMean, max(tCentre) + p.gapMean];  % where FPs may land

truth.nSplits = 0;
truth.nLumps  = 0;

tables = cell(1, p.nObs);
for o = 1:p.nObs
    % Column accumulators for this observer's boxes.
    t0=[]; tEnd=[]; fLow=[]; fHigh=[]; snr=[]; trueCall=[]; nCalls=[];

    % Walk the calls in order. Lumping consumes the next call too, so we
    % advance the index by hand rather than with a for loop.
    k = 1;
    while k <= p.nCalls
        if ~D(k,o), k = k + 1; continue; end   % this observer missed call k

        % Lump: one box spanning call k and call k+1, if the observer also
        % detected k+1. Records nCalls = 2, the information a downstream
        % density correction would need and a bare box would lose.
        doLump = rand < pLump(o) && k < p.nCalls && D(k+1,o);
        if doLump
            start = tCentre(k)   - p.callDur/2 + p.timeJitter*randn;
            stop  = tCentre(k+1) + p.callDur/2 + p.timeJitter*randn;
            [t0,tEnd,fLow,fHigh,snr,trueCall,nCalls] = ...
                emit(t0,tEnd,fLow,fHigh,snr,trueCall,nCalls, ...
                     start, stop, p.band, 5+5*randn, k, 2);
            truth.nLumps = truth.nLumps + 1;
            k = k + 2;
            continue
        end

        % Otherwise one call, optionally split into two shorter boxes that
        % both point at the same call (trueCall = k on each).
        start = tCentre(k) - p.callDur/2 + p.timeJitter*randn;
        dur   = max(p.callDur + p.durJitter*randn, 0.5);
        if rand < pSplit(o)
            mid = start + dur/2; g = 0.5;   % small gap between the two halves
            [t0,tEnd,fLow,fHigh,snr,trueCall,nCalls] = ...
                emit(t0,tEnd,fLow,fHigh,snr,trueCall,nCalls, ...
                     start, mid-g, p.band, 5+5*randn, k, 1);
            [t0,tEnd,fLow,fHigh,snr,trueCall,nCalls] = ...
                emit(t0,tEnd,fLow,fHigh,snr,trueCall,nCalls, ...
                     mid+g, start+dur, p.band, 5+5*randn, k, 1);
            truth.nSplits = truth.nSplits + 1;
        else
            [t0,tEnd,fLow,fHigh,snr,trueCall,nCalls] = ...
                emit(t0,tEnd,fLow,fHigh,snr,trueCall,nCalls, ...
                     start, start+dur, p.band, 5+5*randn, k, 1);
        end
        k = k + 1;
    end

    % False positives, placed clear of every true call so they cannot be
    % confused with one. Lower SNR, as real false positives tend to be.
    for j = 1:nFP(o)
        c = pickClearTime(span, tCentre, p.callDur + 5*p.timeJitter + 5);
        [t0,tEnd,fLow,fHigh,snr,trueCall,nCalls] = ...
            emit(t0,tEnd,fLow,fHigh,snr,trueCall,nCalls, ...
                 c - p.callDur/2, c + p.callDur/2, p.band, -2+4*randn, 0, 1);
    end

    tables{o} = table(t0, tEnd, fLow, fHigh, snr, trueCall, nCalls);
end

truth.D             = D;                 % who detected what (nCalls-by-nObs)
truth.tCentre       = tCentre;
truth.nCalls        = p.nCalls;
truth.nObs          = p.nObs;
truth.detectedCalls = find(any(D, 2));   % calls seen by at least one observer
end

% -------------------------------------------------------------------------
function [t0,tEnd,fLow,fHigh,snr,trueCall,nCalls] = ...
        emit(t0,tEnd,fLow,fHigh,snr,trueCall,nCalls, s, e, band, snrVal, tc, nc)
% EMIT  Append one detection box to this observer's growing columns.
%   Keeps genScenario readable by hiding the repeated bookkeeping. tc is the
%   true-call id (0 = false positive); nc is the number of true calls the box
%   covers (2 = lumped).
t0(end+1,1)       = s;              %#ok<*AGROW>
tEnd(end+1,1)     = e;
fLow(end+1,1)     = band(1);
fHigh(end+1,1)    = band(2);
snr(end+1,1)      = snrVal;
trueCall(end+1,1) = tc;
nCalls(end+1,1)   = nc;
end

% -------------------------------------------------------------------------
function c = pickClearTime(span, tCentre, minSep)
% PICKCLEARTIME  A random time at least minSep from every true call centre.
%   Ensures false positives land in genuine gaps, so a false positive is
%   never accidentally the same event as a real call.
for tries = 1:1000
    c = span(1) + rand*(span(2) - span(1));
    if all(abs(c - tCentre) > minSep), return; end
end
error('Could not place a false positive clear of true calls; widen span.');
end
