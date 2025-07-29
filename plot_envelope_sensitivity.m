function plot_envelope_sensitivity(summaryTable, costTable, figuresDir)
% PLOT_ENVELOPE_SENSITIVITY Analyze sensitivity to building envelope tightness
if isempty(summaryTable) || isempty(costTable)
    warning('plot_envelope_sensitivity: no data provided, skipping plot.');
    return;
end
figure('Position',[100 100 1200 800],'Visible','off');

%% Calculate sensitivity indices
scenarios = unique(summaryTable(~strcmp(summaryTable.mode,'baseline'), ...
    {'location','filterType','mode'}));

nScenarios = height(scenarios);
sensitivity = table();

for i = 1:nScenarios
    loc = scenarios.location{i};
    filt = scenarios.filterType{i};
    mode = scenarios.mode{i};

    % Get tight and leaky data
    tightSum = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode) & ...
        strcmp(summaryTable.leakage,'tight'), :);
    leakySum = summaryTable(strcmp(summaryTable.location,loc) & ...
        strcmp(summaryTable.filterType,filt) & ...
        strcmp(summaryTable.mode,mode) & ...
        strcmp(summaryTable.leakage,'leaky'), :);

    if isempty(tightSum) || isempty(leakySum), continue; end

    % Calculate percentage change from tight to leaky
    pm25_change = 100 * (leakySum.avg_indoor_PM25 - tightSum.avg_indoor_PM25) / tightSum.avg_indoor_PM25;
    pm10_change = 100 * (leakySum.avg_indoor_PM10 - tightSum.avg_indoor_PM10) / tightSum.avg_indoor_PM10;
    cost_change = 100 * (leakySum.total_cost - tightSum.total_cost) / tightSum.total_cost;

    % Filter life change (note: shorter life in leaky = negative change)
    if ~isnan(tightSum.filter_replaced) && ~isnan(leakySum.filter_replaced)
        filter_change = 100 * (leakySum.filter_replaced - tightSum.filter_replaced) / tightSum.filter_replaced;
    else
        filter_change = NaN;
    end

    % Get cost-effectiveness data
    hasLeakCol = ismember('leakage', costTable.Properties.VariableNames);
    hasBoundCols = all(ismember({'percent_PM25_reduction_lower','percent_PM25_reduction_upper',...
        'cost_per_AQI_hour_avoided_lower','cost_per_AQI_hour_avoided_upper'}, ...
        costTable.Properties.VariableNames));

    if hasLeakCol
        tightCost = costTable(strcmp(costTable.location,loc) & ...
            strcmp(costTable.filterType,filt) & ...
            strcmp(costTable.mode,mode) & ...
            strcmp(costTable.leakage,'tight'), :);
        leakyCost = costTable(strcmp(costTable.location,loc) & ...
            strcmp(costTable.filterType,filt) & ...
            strcmp(costTable.mode,mode) & ...
            strcmp(costTable.leakage,'leaky'), :);

        if ~isempty(tightCost) && ~isempty(leakyCost)
            effectiveness_change = leakyCost.percent_PM25_reduction - tightCost.percent_PM25_reduction;
            cost_per_aqi_change = 100 * (leakyCost.cost_per_AQI_hour_avoided - ...
                tightCost.cost_per_AQI_hour_avoided) / tightCost.cost_per_AQI_hour_avoided;
        else
            effectiveness_change = NaN;
            cost_per_aqi_change = NaN;
        end
    elseif hasBoundCols
        rowCost = costTable(strcmp(costTable.location,loc) & ...
            strcmp(costTable.filterType,filt) & ...
            strcmp(costTable.mode,mode), :);
        if ~isempty(rowCost)
            effectiveness_change = rowCost.percent_PM25_reduction_upper - rowCost.percent_PM25_reduction_lower;
            if rowCost.cost_per_AQI_hour_avoided_lower > 0
                cost_per_aqi_change = 100 * (rowCost.cost_per_AQI_hour_avoided_upper - ...
                    rowCost.cost_per_AQI_hour_avoided_lower) / rowCost.cost_per_AQI_hour_avoided_lower;
            else
                cost_per_aqi_change = NaN;
            end
        else
            effectiveness_change = NaN;
            cost_per_aqi_change = NaN;
        end
    else
        effectiveness_change = NaN;
        cost_per_aqi_change = NaN;
    end

    % Build sensitivity row
    row = table({loc}, {filt}, {mode}, pm25_change, pm10_change, cost_change, ...
        filter_change, effectiveness_change, cost_per_aqi_change, ...
        'VariableNames', {'location','filterType','mode', ...
        'pm25_sensitivity','pm10_sensitivity','cost_sensitivity', ...
        'filter_life_sensitivity','effectiveness_change','cost_effectiveness_sensitivity'});

    sensitivity = [sensitivity; row];
end

%% Visualization
% 1. Tornado diagram of sensitivities
subplot(2,2,1);
metrics = {'pm25_sensitivity','pm10_sensitivity','cost_sensitivity','filter_life_sensitivity'};
metricLabels = {'PM2.5 Conc.','PM10 Conc.','Operating Cost','Filter Life'};
meanSens = zeros(length(metrics),1);

for m = 1:length(metrics)
    meanSens(m) = mean(abs(sensitivity.(metrics{m})), 'omitnan');
end

[sortedSens, sortIdx] = sort(meanSens, 'descend');
barh(sortedSens);
set(gca, 'YTick', 1:length(metrics), 'YTickLabel', metricLabels(sortIdx));
xlabel('Mean Sensitivity to Envelope Leakage (% change)');
title('Tornado Diagram: Parameter Sensitivity');
grid on;

% 2. Scenario comparison
subplot(2,2,2);
scenarioLabels = strcat(sensitivity.location, "-", sensitivity.filterType, "-", sensitivity.mode);
x = 1:height(sensitivity);

barData = [sensitivity.pm25_sensitivity, sensitivity.cost_sensitivity, ...
    sensitivity.filter_life_sensitivity];

% Plot grouped bars and ensure smaller bars are drawn on top
[~, sortIdx] = sort(max(abs(barData),[],2), 'ascend');
bar(barData(sortIdx,:), 'grouped');

xlabel('Scenario');
ylabel('Sensitivity (% change from tight to leaky)');
title('Envelope Sensitivity by Scenario');
legend({'PM2.5','Cost','Filter Life'}, 'Location','eastoutside');
set(gca, 'XTick', x, 'XTickLabel', scenarioLabels(sortIdx));
xtickangle(45);
grid on;

% 3. Effectiveness vs Cost Trade-off Changes
subplot(2,2,3);
validIdx = ~isnan(sensitivity.effectiveness_change) & ~isnan(sensitivity.cost_sensitivity);
scatter(sensitivity.cost_sensitivity(validIdx), ...
    sensitivity.effectiveness_change(validIdx), ...
    100, 1:sum(validIdx), 'filled');

xlabel('Cost Increase (%)');
ylabel('Effectiveness Change (% points)');
title('Cost vs Effectiveness Trade-off Impact');
colormap(lines(sum(validIdx)));

% Add quadrant lines
xline(0, '--k');
yline(0, '--k');

% Annotate quadrants with separate text calls
text(max(xlim)*0.7, max(ylim)*0.9, 'Higher Cost,', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
text(max(xlim)*0.7, max(ylim)*0.8, 'More Effective', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
text(min(xlim)*0.3, min(ylim)*0.9, 'Lower Cost,', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
text(min(xlim)*0.3, min(ylim)*0.8, 'Less Effective', ...
    'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
grid on;

% 4. Grouped bar chart by location and filter type
subplot(2,2,4);
locations = unique(sensitivity.location);
filters = unique(sensitivity.filterType);
modes = unique(sensitivity.mode);

groupData = zeros(length(locations)*length(filters), length(modes));
groupLabels = cell(length(locations)*length(filters), 1);
idx = 0;

for l = 1:length(locations)
    for f = 1:length(filters)
        idx = idx + 1;
        groupLabels{idx} = sprintf('%s-%s', locations{l}, filters{f});
        for m = 1:length(modes)
            row = sensitivity(strcmp(sensitivity.location, locations{l}) & ...
                strcmp(sensitivity.filterType, filters{f}) & ...
                strcmp(sensitivity.mode, modes{m}), :);
            if ~isempty(row)
                % Use absolute cost sensitivity as the metric
                groupData(idx, m) = abs(row.cost_sensitivity);
            end
        end
    end
end

bar(groupData);
set(gca, 'XTick', 1:idx, 'XTickLabel', groupLabels);
ylabel('Cost Sensitivity (|%|)');
title('Cost Sensitivity by Configuration');
legend(modes, 'Location','eastoutside');
grid on;

% Overall title
sgtitle('Building Envelope Sensitivity Analysis: Impact of Leakage on System Performance', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Save
save_figure(gcf, figuresDir, 'envelope_sensitivity_analysis.png');
close(gcf);
end