function plotScenarioAxes(ax, tables, ch, truth, maxEvents)
% PLOTSCENARIOAXES  Timeline of detections and recovered events.
%   One row per observer. Each detection is a horizontal bar from start to
%   end, coloured by the true call it belongs to (grey = false positive), and
%   drawn thicker if it is a lumped box. The alternating grey bands are the
%   recovered events: every bar inside a band was grouped into one event by
%   the matcher. Along the bottom, a coloured tick marks each true call
%   centre (the ground truth the matcher never sees); a tick with no bars
%   above it is a call every observer missed. Pass maxEvents to zoom to the
%   first N events; Inf shows all.
if nargin < 5 || isempty(maxEvents), maxEvents = Inf; end
hold(ax, 'on');
nObs = truth.nObs;
cmap = lines(max(truth.nCalls, 7));     % a distinct colour per true call

% Decide the time window from the first maxEvents recovered events.
[~, ord] = sort(ch.t0);
chS   = ch(ord, :);
nShow = min(maxEvents, height(chS));
pad   = 0.02 * (chS.tEnd(nShow) - chS.t0(1));
xlo   = chS.t0(1)      - pad;
xhi   = chS.tEnd(nShow) + pad;

% Shaded bands = recovered events. Shade alternate events so that two
% events sitting side by side are still visually separable.
for e = 1:nShow
    if mod(e,2) == 0
        patch(ax, [chS.t0(e) chS.tEnd(e) chS.tEnd(e) chS.t0(e)], ...
                  [0.4 0.4 nObs+0.6 nObs+0.6], [0.85 0.85 0.85], ...
                  'EdgeColor','none', 'FaceAlpha', 0.5);
    end
end

% Detection bars, coloured by true call, one row per observer.
for o = 1:nObs
    d = tables{o};
    for r = 1:height(d)
        if d.t0(r) > xhi || d.tEnd(r) < xlo, continue; end   % outside window
        if d.trueCall(r) > 0
            col = cmap(mod(d.trueCall(r)-1, size(cmap,1)) + 1, :);
        else
            col = [0.6 0.6 0.6];         % false positive
        end
        lw = 4 + 2*(d.nCalls(r) > 1);    % thicker bar marks a lumped box
        line(ax, [d.t0(r) d.tEnd(r)], [o o], 'Color', col, 'LineWidth', lw);
    end
end

% Ground-truth call centres, the truth the matcher never sees. Each true
% call gets a tick in its own colour, so a tick with no bars of that colour
% above it is a call every observer missed. That call has an all-zero
% capture history and cannot appear as an event; it is exactly the class a
% capture-recapture analysis exists to estimate.
for k = 1:truth.nCalls
    xc = truth.tCentre(k);
    if xc < xlo || xc > xhi, continue; end
    col = cmap(mod(k-1, size(cmap,1)) + 1, :);
    plot(ax, xc, 0.25, '^', 'MarkerSize', 5, ...
        'MarkerFaceColor', col, 'MarkerEdgeColor', 'none');
end

hold(ax, 'off');
xlim(ax, [xlo xhi]);
ylim(ax, [0.05 nObs+0.6]);
ylabels = [{'true calls'}, arrayfun(@(o) sprintf('obs %d', o), 1:nObs, 'uni', 0)];
set(ax, 'YTick', [0.25, 1:nObs], 'YTickLabel', ylabels);
xlabel(ax, 'time (s)'); grid(ax, 'on');
end
