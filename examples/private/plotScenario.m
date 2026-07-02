function plotScenario(tables, ch, truth, titleStr)
% PLOTSCENARIO  Draw a labelled timeline for a rung (all events by default).
figure('Units','pixels','Position',[50 50 1000 260]);
plotScenarioAxes(gca, tables, ch, truth, Inf);
title(titleStr, 'Interpreter','none', 'FontWeight','bold');
end
