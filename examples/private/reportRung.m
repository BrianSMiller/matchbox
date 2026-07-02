function reportRung(name, res)
% REPORTRUNG  Narrated summary for an assertion rung. The [PASS] tag is the
%   quiet validation; the sentences are the illustrative part.
fprintf('\nExample %s   [%s]\n', name, tf(res.pass, 'PASS', 'FAIL'));
fprintf('   %d true calls: %d detected by one or more observers, %d missed by all.\n', ...
    res.nCallsTrue, res.nCallsExpected, res.nUnobserved);
freqStr = strjoin(arrayfun(@(j) sprintf('%d obs: %d', j, res.captureFreq(j)), ...
    1:numel(res.captureFreq), 'uni', 0), '   ');
fprintf('   recovered as %d events. Capture frequency   %s\n', res.nEvents, freqStr);
if res.nFPevents > 0 || res.nMerged > 0
    fprintf('   false-positive events: %d   merged events: %d\n', ...
        res.nFPevents, res.nMerged);
end
end
