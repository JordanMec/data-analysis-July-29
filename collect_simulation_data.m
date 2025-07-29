function simulationData = collect_simulation_data(dataDir)
% List of the 20 filenames
filenames = {
    'adams_tight_baseline.mat', ...
    'adams_tight_merv_active.mat',    'adams_tight_merv_always_on.mat', ...
    'adams_tight_hepa_active.mat',    'adams_tight_hepa_always_on.mat', ...
    'adams_leaky_baseline.mat', ...
    'adams_leaky_merv_active.mat',    'adams_leaky_merv_always_on.mat', ...
    'adams_leaky_hepa_active.mat',    'adams_leaky_hepa_always_on.mat', ...
    'baker_tight_baseline.mat', ...
    'baker_tight_merv_active.mat',    'baker_tight_merv_always_on.mat', ...
    'baker_tight_hepa_active.mat',    'baker_tight_hepa_always_on.mat', ...
    'baker_leaky_baseline.mat', ...
    'baker_leaky_merv_active.mat',    'baker_leaky_merv_always_on.mat', ...
    'baker_leaky_hepa_active.mat',    'baker_leaky_hepa_always_on.mat'
    };

simulationData = struct();
idx = 0;

missing = {};

for i = 1:length(filenames)
    filename = filenames{i};
    filepath = fullfile(dataDir, filename);

    % Require every expected file. Any missing file triggers an error so
    % downstream analyses always have a complete set of scenarios.
    if ~exist(filepath, 'file')
        missing{end+1} = filename; %#ok<AGROW>
        continue;
    end
    loaded = load(filepath);
    if isstruct(loaded) && isfield(loaded, 'data')
        dataStruct = loaded.data;
    else
        dataStruct = loaded;
    end

    % Extract metadata from filename
    parts = split(erase(filename, '.mat'), '_');
    location = parts{1};           % e.g., adams or baker
    leakage = parts{2};            % tight or leaky

    % Determine filter type and operating mode from remaining parts
    switch numel(parts)
        case 3
            % <location>_<leakage>_baseline
            filterType = 'baseline';
            mode = 'baseline';
        case 4
            % <location>_<leakage>_<filterType>_<mode>
            filterType = parts{3};
            mode = parts{4};
        case 5
            % <location>_<leakage>_<filterType>_always_on
            filterType = parts{3};
            mode = strjoin(parts(4:5), '_');
        otherwise
            error('Unexpected filename format: %s', filename);
    end

    % Store into structured array
    idx = idx + 1;
    simulationData(idx).filename = filename;
    simulationData(idx).location = location;
    simulationData(idx).leakage = leakage;
    simulationData(idx).filterType = filterType;
    simulationData(idx).mode = mode;

    % Assign data arrays
    simulationData(idx).outdoor_PM25 = dataStruct.outdoor_PM25;
    simulationData(idx).outdoor_PM10 = dataStruct.outdoor_PM10;
    simulationData(idx).indoor_PM25 = dataStruct.indoor_PM25;
    simulationData(idx).indoor_PM10 = dataStruct.indoor_PM10;
    simulationData(idx).total_cost = dataStruct.total_cost;
    simulationData(idx).filter_life_series = dataStruct.filter_life_series;

    % Air change rate time series may be stored under different field names
    if isfield(dataStruct, 'ach_series')
        simulationData(idx).ach_series = dataStruct.ach_series;
    elseif isfield(dataStruct, 'ach')
        simulationData(idx).ach_series = dataStruct.ach;
    else
        simulationData(idx).ach_series = [];
    end

end

if ~isempty(missing)
    error('Missing required simulation files: %s', strjoin(missing, ', '));
elseif idx == 0
    error('No simulation files were loaded from %s', dataDir);
else
    fprintf('✓ Loaded %d simulation files successfully\n', idx);
end
end