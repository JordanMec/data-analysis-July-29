function bar_with_error(categories, values, errLow, errHigh, color, yLabel, xLabel, titleStr, savePath)
if nargin < 5 || isempty(color)
    color = [0.2 0.6 0.8];
end
fig = create_hidden_figure();
nexttile;
bar(categorical(categories), values, 'FaceColor', color);
hold on;
errorbar(1:numel(values), values, errLow, errHigh, 'k','LineStyle','none');
ylabel(yLabel);
xlabel(xLabel);
title(titleStr);
xtickangle(45);
grid on;
if nargin >= 9 && ~isempty(savePath)
    outDir = fileparts(savePath);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    saveas(fig, savePath);
end
close(fig);
end