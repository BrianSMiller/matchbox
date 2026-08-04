function publishDocs
% publishDocs  Publish the matchbox example gallery to HTML.
%   Renders examples/gallery.m to examples/html/ so it can
%   be shared and viewed outside MATLAB. Run from anywhere:
%       publishDocs
%
% Mirrors the bsnr publishDocs workflow.

examplesDir = fileparts(mfilename('fullpath'));
repoRoot    = fileparts(examplesDir);
htmlDir     = fullfile(examplesDir, 'html');

% Ensure the matchers are on the path for evaluation.
addpath(repoRoot, '-begin');
addpath(examplesDir, '-begin');
if ~exist(htmlDir, 'dir'), mkdir(htmlDir); end

opts = struct( ...
    'format',        'html', ...
    'outputDir',     htmlDir, ...
    'evalCode',      true, ...
    'showCode',      true, ...
    'maxWidth',      1000, ...
    'maxHeight',     [], ...
    'stylesheet',    '');

gallery = fullfile(examplesDir, 'gallery.m');
outFile = publish(gallery, opts);

fprintf('Published:\n  %s\n', outFile);
end
