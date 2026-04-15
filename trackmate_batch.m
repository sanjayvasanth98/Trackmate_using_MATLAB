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
clc;
% Root directory where one sub-folder per case will be created
outputRoot = 'E:\March Re 90,000 inception data\Processed images\testing\testing 2';

% Define each case: name + the folders that belong to it.
% Add or remove cases(N) blocks as needed.
% Each case gets its own output folder:  <outputRoot>\<name>\
% Files are named:  <name>_1.xml, <name>_2.xml, ...

cases(1).name    = 'P10S20';
cases(1).folders = {"E:\March Re 90,000 inception data\Processed images\testing\testing 1\P10S20"};

cases(2).name    = 'P10S30';
cases(2).folders = {"E:\March Re 90,000 inception data\Processed images\testing\testing 1\P10S30"};

cases(3).name    = 'P10S50';
cases(3).folders = {"E:\March Re 90,000 inception data\Processed images\testing\testing 1\P10S50"};

% cases(3).name    = 'P20S40';
% cases(3).folders = {
%     'C:\path\to\P20S40\folder1'
% };
% Add more cases below following the same pattern:
% cases(4).name    = 'PXXSYY';
% cases(4).folders = { 'C:\path\to\...' };

%% ============================================================
%%  JAVA / TRACKMATE IMPORTS
%% ============================================================
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

            % If the AVI loaded as a z-stack (slices) instead of a
            % time series (frames), re-interpret it so TrackMate can track.
            nFrames = imp.getNFrames();
            nSlices = imp.getNSlices();
            fprintf('  Loaded: %d x %d  |  channels=%d  slices=%d  frames=%d\n', ...
                imp.getWidth(), imp.getHeight(), imp.getNChannels(), nSlices, nFrames);

            if nFrames == 1 && nSlices > 1
                fprintf('  Converting z-stack (%d slices) to time series...\n', nSlices);
                imp = ij.plugin.HyperStackConverter.toHyperStack(imp, 1, 1, nSlices);
                fprintf('  After conversion: slices=%d  frames=%d\n', ...
                    imp.getNSlices(), imp.getNFrames());
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
            detMap.put('TARGET_CHANNEL',      int32(1));
            detMap.put('INTENSITY_THRESHOLD', 254.0);
            detMap.put('SIMPLIFY_CONTOURS',   false);
            settings.detectorSettings = detMap;

            % No spot filters

            %--- Tracker: Advanced Kalman Filter ----------------------
            settings.trackerFactory  = AdvancedKalmanTrackerFactory();
            settings.trackerSettings = settings.trackerFactory.getDefaultSettings();
            settings.trackerSettings.put('LINKING_MAX_DISTANCE',  15.0);
            settings.trackerSettings.put('KALMAN_SEARCH_RADIUS',   22.0);
            settings.trackerSettings.put('MAX_FRAME_GAP',          int32(1));
            settings.trackerSettings.put('ALLOW_GAP_CLOSING',      false);
            settings.trackerSettings.put('ALLOW_TRACK_SPLITTING',  true);
            settings.trackerSettings.put('SPLITTING_MAX_DISTANCE', 20.0);
            settings.trackerSettings.put('ALLOW_TRACK_MERGING',    false);

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

            nSpotsFiltered  = model.getSpots().getNSpots(true);
            nTracksFiltered = model.getTrackModel().nTracks(true);
            fprintf('  Spots (after filter): %d  |  Tracks (after filter): %d\n', ...
                nSpotsFiltered, nTracksFiltered);
            fprintf('  Saved: %s\n', xmlPath);

            imp.close();

        catch ME
            fprintf('  EXCEPTION on file %d: %s\n', i, ME.message);
            try; imp.close(); catch; end
        end
    end % inner file loop

    fprintf('\nCase %s complete. Results in: %s\n', caseName, outputFolder);

end % outer case loop

fprintf('\n=== All cases complete ===\n');

%% ============================================================
%%  DISPLAY RESULTS  –– run this section independently
%%  (Ctrl+Enter on this cell, or click "Run Section")
%%
%%  Set showDisplay = true, fill in the XML and AVI paths below,
%%  then run only this section to inspect any result without
%%  re-running the full batch.
%% ============================================================

showDisplay = true;   % <-- set to true to open the displayer

% Path to the TrackMate XML you want to inspect
displayXml = "E:\March Re 90,000 inception data\Processed images\testing\testing 2\P10S20\P10S20_1.xml";

% Path to the matching source AVI
displayAvi = "E:\March Re 90,000 inception data\Processed images\testing\testing 1\P10S20\P10S20_1.avi";

if showDisplay
    import ij.IJ
    import fiji.plugin.trackmate.io.TmXmlReader
    import fiji.plugin.trackmate.SelectionModel
    import fiji.plugin.trackmate.gui.displaysettings.DisplaySettingsIO
    import fiji.plugin.trackmate.visualization.hyperstack.HyperStackDisplayer

    % Open source image
    impD = IJ.openImage(displayAvi);
    if isempty(impD)
        error('Display: could not open AVI – check the displayAvi path:\n  %s', displayAvi);
    end

    % Convert z-stack to time series if needed
    if impD.getNFrames() == 1 && impD.getNSlices() > 1
        impD = ij.plugin.HyperStackConverter.toHyperStack(impD, 1, 1, impD.getNSlices());
    end
    impD.show();

    % Load model and settings from the saved XML
    reader   = TmXmlReader(java.io.File(displayXml));
    modelD   = reader.getModel();

    % Display with track overlay – tracks shown backward in time
    ds = DisplaySettingsIO.readUserDefault();
    ds.setLineThickness(1.5);
    % Access the nested Java enum via javaMethod (MATLAB cannot use dot
    % notation on inner classes – the $ suffix is Java's inner-class syntax)
    trackModeBackward = javaMethod('valueOf', ...
        'fiji.plugin.trackmate.gui.displaysettings.DisplaySettings$TrackDisplayMode', ...
        'LOCAL_BACKWARD');
    ds.setTrackDisplayMode(trackModeBackward);
    selectionModel = SelectionModel(modelD);
    displayer = HyperStackDisplayer(modelD, selectionModel, impD, ds);
    displayer.render();
    displayer.refresh();

    % Print summary to command window
    display(modelD.toString());

    % ---- Animate forward – track tail shows traversed path (LOCAL_BACKWARD)
    % The video plays frame 1 → N while the overlay draws the past trajectory
    % behind each particle at each step.  Press Ctrl+C to stop early.
    animFps     = 10;                          % playback speed (frames/sec)
    nLoops      = 3;                           % how many times to repeat
    delayMs     = int32(round(1000/animFps));  % ms between frames
    totalFrames = impD.getNFrames();

    fprintf('Animating %d frames forward at %d fps (%d loop(s))...\n', ...
        totalFrames, animFps, nLoops);

    for loop = 1:nLoops
        for t = 1:totalFrames
            impD.setT(t);
            impD.updateAndDraw();
            java.lang.Thread.sleep(delayMs);
        end
    end
    fprintf('Playback complete.\n');
end
