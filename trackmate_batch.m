%% TrackMate Batch Processing Script
% Batch processes binary .avi files across multiple folders using TrackMate.
%
% Detector : Thresholding Detector
%            - Intensity threshold : 254
%            - Simplify contours   : false
% Tracker  : Advanced Kalman Filter
%            - Initial search radius : 15 px
%            - Search radius         : 22 px
%            - Max frame gap         : 1 frame
%            - Allow track splitting : true
%            - Allow track merging   : false
% Filters  : No spot filters | Track displacement > 1 px
% Output   : TrackMate XML per file  ->  <outputRoot>/<caseName>/<caseName>_1.xml, _2.xml ...
%
% NOTE on tracker class name: If AdvancedKalmanTrackerFactory fails to load,
% open one of your videos in the TrackMate GUI with your settings, save the
% XML, then search that XML for "trackerFactory" to find the exact class name
% and update the import + trackerFactory lines below.

%% ============================================================
%%  USER CONFIGURATION  –– edit only this section
%% ============================================================

% Root directory where one sub-folder per case will be created
outputRoot = 'C:\path\to\output_root';

% Define each case: name + the folders that belong to it.
% Add or remove cases(N) blocks as needed.
% Each case gets its own output folder:  <outputRoot>\<name>\
% Files are named:  <name>_1.xml, <name>_2.xml, ...

cases(1).name    = 'P10S20';
cases(1).folders = {
    'C:\path\to\P10S20\folder1', ...
    'C:\path\to\P10S20\folder2'
};

cases(2).name    = 'P15S30';
cases(2).folders = {
    'C:\path\to\P15S30\folder1', ...
    'C:\path\to\P15S30\folder2'
};

cases(3).name    = 'P20S40';
cases(3).folders = {
    'C:\path\to\P20S40\folder1'
};

% Add more cases below following the same pattern:
% cases(4).name    = 'PXXSYY';
% cases(4).folders = { 'C:\path\to\...' };

%% ============================================================
%%  JAVA / TRACKMATE IMPORTS
%% ============================================================
import java.lang.Integer
import java.lang.Double
import java.lang.Boolean
import ij.IJ
import fiji.plugin.trackmate.TrackMate
import fiji.plugin.trackmate.Model
import fiji.plugin.trackmate.Settings
import fiji.plugin.trackmate.Logger
import fiji.plugin.trackmate.features.FeatureFilter
import fiji.plugin.trackmate.detection.ThresholdDetectorFactory
import fiji.plugin.trackmate.tracking.kalman.AdvancedKalmanTrackerFactory
import fiji.plugin.trackmate.io.TmXmlWriter

%% ============================================================
%%  OUTER LOOP – iterate over cases
%% ============================================================
for c = 1:numel(cases)
    caseName     = cases(c).name;
    inputFolders = cases(c).folders;

    fprintf('\n========================================\n');
    fprintf('CASE: %s\n', caseName);
    fprintf('========================================\n');

    %------------------------------------------------------------------
    % Create output folder  <outputRoot>/<caseName>/
    %------------------------------------------------------------------
    outputFolder = fullfile(outputRoot, caseName);
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
        fprintf('Created output folder: %s\n', outputFolder);
    end

    %------------------------------------------------------------------
    % Collect .avi files for this case (recursive search)
    % Requires MATLAB R2016b+ for the ** wildcard in dir().
    %------------------------------------------------------------------
    aviFiles = {};
    for f = 1:numel(inputFolders)
        hits = dir(fullfile(inputFolders{f}, '**', '*.avi'));
        for k = 1:numel(hits)
            aviFiles{end+1} = fullfile(hits(k).folder, hits(k).name); %#ok<SAGROW>
        end
    end

    if isempty(aviFiles)
        fprintf('  WARNING: No .avi files found for case %s – skipping.\n', caseName);
        continue;
    end
    fprintf('Found %d .avi file(s).\n\n', numel(aviFiles));

    %------------------------------------------------------------------
    % Inner loop – process each file in this case
    %------------------------------------------------------------------
    for i = 1:numel(aviFiles)
        aviPath = aviFiles{i};
        fprintf('[%d/%d] Processing: %s\n', i, numel(aviFiles), aviPath);

        try
            % Open image -----------------------------------------------
            imp = IJ.openImage(aviPath);
            if isempty(imp)
                fprintf('  WARNING: Could not open file – skipping.\n');
                continue;
            end
            imp.show();

            % Model ----------------------------------------------------
            model = Model();
            model.setLogger(Logger.IJ_LOGGER);

            % Settings -------------------------------------------------
            settings = Settings(imp);

            %--- Detector: Thresholding Detector ----------------------
            settings.detectorFactory = ThresholdDetectorFactory();
            detMap = java.util.HashMap();
            detMap.put('INTENSITY_THRESHOLD', Double.valueOf(254.0));
            detMap.put('SIMPLIFY_CONTOURS',   Boolean.FALSE);
            settings.detectorSettings = detMap;

            % No spot filters

            %--- Tracker: Advanced Kalman Filter ----------------------
            settings.trackerFactory  = AdvancedKalmanTrackerFactory();
            settings.trackerSettings = settings.trackerFactory.getDefaultSettings();
            settings.trackerSettings.put('INITIAL_SEARCH_RADIUS', Double.valueOf(15.0));
            settings.trackerSettings.put('KALMAN_SEARCH_RADIUS',  Double.valueOf(22.0));
            settings.trackerSettings.put('MAX_FRAME_GAP',          Integer.valueOf(1));
            settings.trackerSettings.put('ALLOW_TRACK_SPLITTING',  Boolean.TRUE);
            settings.trackerSettings.put('ALLOW_TRACK_MERGING',    Boolean.FALSE);

            %--- Feature analyzers (required for track filters) -------
            settings.addAllAnalyzers();

            %--- Track filter: TRACK_DISPLACEMENT > 1 px --------------
            settings.addTrackFilter(FeatureFilter('TRACK_DISPLACEMENT', 1.0, true));

            % Run TrackMate --------------------------------------------
            trackmate = TrackMate(model, settings);

            ok = trackmate.checkInput();
            if ~ok
                fprintf('  ERROR (checkInput): %s\n', char(trackmate.getErrorMessage()));
                imp.close();
                continue;
            end

            ok = trackmate.process();
            if ~ok
                fprintf('  ERROR (process): %s\n', char(trackmate.getErrorMessage()));
                imp.close();
                continue;
            end

            % Export TrackMate XML -------------------------------------
            xmlName = sprintf('%s_%d.xml', caseName, i);
            xmlPath = fullfile(outputFolder, xmlName);

            writer = TmXmlWriter(java.io.File(xmlPath));
            writer.appendModel(model);
            writer.appendSettings(settings);
            writer.writeToFile();

            fprintf('  Saved: %s\n', xmlPath);

            % Close image – free memory before next file ---------------
            imp.close();

        catch ME
            fprintf('  EXCEPTION on file %d: %s\n', i, ME.message);
            try; imp.close(); catch; end
        end
    end % inner file loop

    fprintf('\nCase %s complete. Results in: %s\n', caseName, outputFolder);

end % outer case loop

fprintf('\n=== All cases complete ===\n');
