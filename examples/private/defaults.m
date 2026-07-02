function p = defaults(regime)
% DEFAULTS  Parameter set for a scenario regime.
%   Returns a struct of knobs that genScenario understands. Two regimes are
%   provided: 'zcall' (one caller, calls far apart, the easy case) and
%   'chorus' (several animals, calls close together, the hard case). Rungs
%   start from one of these and then flip individual knobs.
if nargin < 1, regime = 'zcall'; end

% Knobs shared by both regimes (rungs override these as needed).
p.nObs       = 2;      % number of observers
p.pDetect    = 1;      % detection prob: scalar, 1-by-nObs, or nCalls-by-nObs logical
p.timeJitter = 0;      % s, sd of per-detection start-time offset between observers
p.durJitter  = 1;      % s, sd of box duration
p.nFP        = 0;      % false positives: scalar or 1-by-nObs count
p.pSplit     = 0;      % prob an observer splits a call into two boxes
p.pLump      = 0;      % prob an observer lumps a call with the next into one box
p.band       = [26 28];% Hz, frequency band of the boxes (single call type)
p.minGap     = [];     % [] = auto separable spacing; a number allows tight spacing
p.seed       = 42;     % rng seed, for reproducible scenarios

% Regime-specific timing.
switch regime
    case 'zcall'       % single caller, well separated: clustering is trivial
        p.nCalls = 24; p.callDur = 12; p.gapMean = 80; p.gapJitter = 20;
    case 'chorus'      % several animals, close spaced: clustering degrades
        p.nCalls = 40; p.callDur = 9;  p.gapMean = 14; p.gapJitter = 4;
        p.timeJitter = 3; p.minGap = 4;
    otherwise
        error('Unknown regime: %s', regime);
end
end
