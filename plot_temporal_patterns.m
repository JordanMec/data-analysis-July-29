function plot_temporal_patterns(temporalAnalysis, saveDir)
%PLOT_TEMPORAL_PATTERNS Visualize diurnal and longer-term trends in I/O ratios
%   plot_temporal_patterns(temporalAnalysis, saveDir) creates several figures
%   describing temporal behavior of filtration performance in active mode.

if isempty(fieldnames(temporalAnalysis))
    warning('plot_temporal_patterns: no data provided, skipping plot.');
    return;
end

figure('Position', [100 100 1400 1000], 'Visible', 'off');

configs = fieldnames(temporalAnalysis);

% Diurnal patterns
subplot(2, 2, 1);
hold on;
colors = lines(length(configs));

for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'diurnal_io_ratio')
        if isfield(data, 'diurnal_io_ratio_lower')
            fill([0:23 fliplr(0:23)], ...
                 [data.diurnal_io_ratio_lower' fliplr(data.diurnal_io_ratio_upper')], ...
                 colors(i,:), 'FaceAlpha',0.2,'EdgeColor','none');
        end
        plot(0:23, data.diurnal_io_ratio, 'o-', 'Color', colors(i,:), ...
            'LineWidth', 2, 'MarkerSize', 6);
    end
end

xlabel('Hour of Day');
ylabel('Average I/O Ratio');
title('Diurnal Pattern of Filtration Performance');
legend(strrep(configs, '_', ' '), 'Location', 'best');
grid on;
xlim([-0.5 23.5]);

% Temporal stability
subplot(2, 2, 2);
stability_scores = [];
stab_lower = [];
stab_upper = [];
labels = {};

for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'stability_score')
        stability_scores(i) = data.stability_score;
        if isfield(data, 'stability_score_lower')
            stab_lower(i) = data.stability_score_lower;
            stab_upper(i) = data.stability_score_upper;
        else
            stab_lower(i) = NaN; stab_upper(i) = NaN;
        end
        labels{i} = sprintf('%s\n%s Filter', strrep(data.location, '_', ' '), upper(data.filterType));
    end
end

bar(stability_scores, 'FaceColor', [0.4 0.6 0.8]);
hold on;
if any(~isnan(stab_lower))
    errorbar(1:length(stability_scores), stability_scores, ...
        stability_scores - stab_lower, stab_upper - stability_scores, 'k.', 'LineStyle','none');
end
set(gca, 'XTick', 1:length(labels), 'XTickLabel', labels);
ylabel('Stability Score');
title('Temporal Performance Stability');
grid on;

% Performance degradation over time
subplot(2, 2, [3 4]);
hold on;

for i = 1:length(configs)
    config = configs{i};
    data = temporalAnalysis.(config);
    if isfield(data, 'performance_trend')
        days = 1:length(data.performance_trend);
        if isfield(data, 'performance_trend_tight')
            fill([days fliplr(days)], ...
                 [data.performance_trend_tight fliplr(data.performance_trend_leaky)], ...
                 colors(i,:), 'FaceAlpha',0.2,'EdgeColor','none');
        end
        plot(days, data.performance_trend, 'o-', 'Color', colors(i,:), ...
            'LineWidth', 1.5, 'MarkerSize', 4);
    end
end

xlabel('Day');
ylabel('Daily Average I/O Ratio');
title('Performance Trend Over Time');
legend(strrep(configs, '_', ' '), 'Location', 'best');
grid on;

sgtitle('Temporal Patterns in Active Mode Performance', 'FontSize', 14, 'FontWeight', 'bold');
save_figure(gcf, saveDir, 'temporal_patterns.png');
close(gcf);
end