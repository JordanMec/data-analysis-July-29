function eventAnalysis = detect_analyze_pollution_events(activeData, params)
% Detect and analyze response to outdoor pollution events

eventAnalysis = struct();
configs = fieldnames(activeData);

for i = 1:length(configs)

    config = configs{i};
    data = activeData.(config);

    eventAnalysis.(config) = struct();
    eventAnalysis.(config).location = data.location;
    eventAnalysis.(config).filterType = data.filterType;

    % Detect PM2.5 events in outdoor data
    pm25_baseline = prctile(data.outdoor_PM25, params.baseline.percentile);
    pm25_threshold = pm25_baseline * params.detection.threshold_multiplier_pm25;
    pm25_events = find_pollution_events(data.outdoor_PM25, pm25_threshold, params.detection.min_duration_hours, params.detection.threshold_multiplier_pm25);

    % Detect PM10 events in outdoor data
    pm10_baseline = prctile(data.outdoor_PM10, params.baseline.percentile);
    pm10_threshold = pm10_baseline * params.detection.threshold_multiplier_pm10;
    pm10_events = find_pollution_events(data.outdoor_PM10, pm10_threshold, params.detection.min_duration_hours, params.detection.threshold_multiplier_pm10);

    % Bounds using tight and leaky indoor data
    pm25_base_tight = prctile(data.indoor_PM25_tight, params.baseline.percentile);
    pm25_base_leaky = prctile(data.indoor_PM25_leaky, params.baseline.percentile);
    pm25_events_tight = find_pollution_events(data.indoor_PM25_tight, pm25_base_tight * params.detection.threshold_multiplier_pm25, params.detection.min_duration_hours, params.detection.threshold_multiplier_pm25);
    pm25_events_leaky = find_pollution_events(data.indoor_PM25_leaky, pm25_base_leaky * params.detection.threshold_multiplier_pm25, params.detection.min_duration_hours, params.detection.threshold_multiplier_pm25);

    pm10_base_tight = prctile(data.indoor_PM10_tight, params.baseline.percentile);
    pm10_base_leaky = prctile(data.indoor_PM10_leaky, params.baseline.percentile);
    pm10_events_tight = find_pollution_events(data.indoor_PM10_tight, pm10_base_tight * params.detection.threshold_multiplier_pm10, params.detection.min_duration_hours, params.detection.threshold_multiplier_pm10);
    pm10_events_leaky = find_pollution_events(data.indoor_PM10_leaky, pm10_base_leaky * params.detection.threshold_multiplier_pm10, params.detection.min_duration_hours, params.detection.threshold_multiplier_pm10);

    total_tight = length(pm25_events_tight) + length(pm10_events_tight);
    total_leaky = length(pm25_events_leaky) + length(pm10_events_leaky);

    eventAnalysis.(config).pm25_events = pm25_events;
    eventAnalysis.(config).pm10_events = pm10_events;
    eventAnalysis.(config).total_events = mean([total_tight, total_leaky]);
    eventAnalysis.(config).total_events_bounds = [min(total_tight, total_leaky), max(total_tight, total_leaky)];

    % Analyze event characteristics using indoor events for duration bounds
    if ~isempty(pm25_events_tight)
        dur_tight = mean([pm25_events_tight.duration]);
    else
        dur_tight = NaN;
    end
    if ~isempty(pm25_events_leaky)
        dur_leaky = mean([pm25_events_leaky.duration]);
    else
        dur_leaky = NaN;
    end

    % Compute event severities for tight and leaky indoor cases
    if ~isempty(pm25_events_tight)
        severities_tight = [pm25_events_tight.peak_value] ./ [pm25_events_tight.baseline];
    else
        severities_tight = [];
    end
    if ~isempty(pm25_events_leaky)
        severities_leaky = [pm25_events_leaky.peak_value] ./ [pm25_events_leaky.baseline];
    else
        severities_leaky = [];
    end

    if ~isempty(pm25_events)
        severities = [pm25_events.peak_value] ./ [pm25_events.baseline];
        eventAnalysis.(config).event_severities = severities;
        eventAnalysis.(config).event_severities_tight = severities_tight;
        eventAnalysis.(config).event_severities_leaky = severities_leaky;

        eventAnalysis.(config).avg_event_duration = mean([dur_tight, dur_leaky], 'omitnan');
        eventAnalysis.(config).avg_event_duration_bounds = [min(dur_tight, dur_leaky), max(dur_tight, dur_leaky)];

        % Analyze response to events
        response_metrics = analyze_event_responses(pm25_events, data, params);
        eventAnalysis.(config).pm25_response = response_metrics;
    else
        eventAnalysis.(config).avg_event_duration = NaN;
        eventAnalysis.(config).avg_event_duration_bounds = [NaN, NaN];
        eventAnalysis.(config).event_severities = [];
        eventAnalysis.(config).event_severities_tight = severities_tight;
        eventAnalysis.(config).event_severities_leaky = severities_leaky;
    end
end

end