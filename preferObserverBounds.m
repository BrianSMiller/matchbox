function cht = preferObserverBounds(cht, preferredObs, fallbackObs)
% Thin wrapper: overriding fLow/fHigh with a preferred observer's own
% bounds is a resolve-by-priority, same mechanism as
% resolveObserverColumns -- see that function for the general case.
cht = resolveObserverColumns(cht, {'fLow','fHigh'}, 'priority', [preferredObs, fallbackObs]);
end