# Control TrackMate using MATLAB

Run Fiji's TrackMate from MATLAB to detect particles, link trajectories, and batch-process binary AVI videos. The batch script groups inputs by case, saves one TrackMate XML file per video, and includes an optional viewer for inspecting the results.

## Repository contents

| File | Purpose |
| --- | --- |
| [`trackmate_batch.m`](trackmate_batch.m) | Recursively processes AVI files using a Thresholding Detector and Advanced Kalman Filter tracker; exports XML and provides optional track playback. |
| [`matlab_trackmate.m`](matlab_trackmate.m) | Reference example using the online `FakeTracks.tif` sample, a LoG detector, and a Sparse LAP tracker. Displays tracks and prints a model summary. |

## Requirements and setup

- MATLAB with Java support. The batch script uses recursive `dir` searches and string syntax introduced in R2016b; compatibility also depends on your MATLAB, Java, and Fiji versions.
- Fiji with TrackMate and the detector/tracker classes used by the scripts.
- The ImageJ-MATLAB bridge, initialized before running either script.
- Binary AVI videos readable by ImageJ for batch processing. The reference example requires internet access to download its sample image.

Follow the official [ImageJ-MATLAB setup instructions](https://imagej.net/scripting/matlab) to enable the **ImageJ-MATLAB** update site in Fiji and restart Fiji. Then initialize the bridge from MATLAB, adjusting the path for your installation:

```matlab
addpath('C:/path/to/Fiji.app/scripts');
ImageJ;
```

Download or clone this repository and open its folder in MATLAB:

```bash
git clone https://github.com/sanjayvasanth98/Trackmate_using_MATLAB.git
```

The scripts assume the bridge is already running; they do not initialize it themselves. See the [official TrackMate MATLAB example](https://github.com/trackmate-sc/TrackMate/blob/master/scripts/MATLABExampleScript_1.m) for the upstream startup sequence.

## Batch processing

### 1. Configure input cases and output paths

Open `trackmate_batch.m` and replace the existing `outputRoot` and `cases` definitions in **USER CONFIGURATION** with your own paths. Each case can include several input folders; subfolders are searched automatically.

```matlab
outputRoot = 'C:/data/Results';

cases(1).name = 'CaseA';
cases(1).folders = {
    'C:/data/CaseA/run1'
    'C:/data/CaseA/run2'
};

cases(2).name = 'CaseB';
cases(2).folders = {'C:/data/CaseB'};
```

Remove unused case definitions. If you previously ran the script in the same MATLAB workspace, run `clear cases` before running the revised configuration so old entries do not remain.

Inputs are expected to be binary images with bright foreground particles. The default intensity threshold is **254**, intended for foreground values near 255. Adjust detection settings if your images use a different intensity range.

### 2. Review tracking settings

These values are configured inside the processing loop in `trackmate_batch.m`:

| Setting | Default |
| --- | --- |
| Detector | Thresholding Detector |
| Target channel | 1 |
| Intensity threshold | 254 |
| Simplify contours | `false` |
| Spot filters | None added |
| Tracker | Advanced Kalman Filter |
| Initial search radius (`KALMAN_SEARCH_RADIUS`) | 15 |
| Linking distance (`LINKING_MAX_DISTANCE`) | 22 |
| Maximum frame gap | 1 |
| Gap closing | `false` |
| Track splitting | `true` |
| Splitting distance | 30 |
| Track merging | `false` |
| Track displacement filter | Above 1 |

The script describes distances in pixels and does not explicitly set spatial or time calibration. Check the image calibration before interpreting distances or timing. `MAX_FRAME_GAP` is set to 1 even though `ALLOW_GAP_CLOSING` is false; verify how your installed tracker handles these settings.

### 3. Run the batch

From the repository folder in MATLAB:

```matlab
trackmate_batch
```

For each case, the script recursively finds `*.avi` files, opens each video, and converts a single-frame Z-stack into a time series when needed. It then runs TrackMate, writes the model and settings to XML, and closes the image. Progress, spot/track counts, and errors are printed to the command window. Empty cases and failed files are skipped so processing can continue.

## Output

Results are organized by case and the source video's base filename:

```text
Results/
├── CaseA/
│   ├── video_01.xml
│   └── video_02.xml
└── CaseB/
    └── video_03.xml
```

Each XML contains the TrackMate model and processing settings. The script does not export CSV tables or rendered videos.

**Use unique video basenames within each case.** Input subfolder names are not preserved in the output path, so videos with the same basename in one case target the same XML file. Rerunning a batch also targets existing output filenames; use a new output folder to preserve previous results.

## Inspect saved tracks

At the end of `trackmate_batch.m`, find the **DISPLAY RESULTS** section:

1. Set `showDisplay = true`.
2. Set `displayXml` to a saved XML file and `displayAvi` to its matching source video.
3. Run only that section with MATLAB's **Run Section** command to avoid rerunning the batch.

The viewer overlays tracks with backward-looking trajectory tails while playing frames forward. Playback defaults to **10 frames per second** for **3 loops**; adjust `animFps` and `nLoops` in the section. Press **Ctrl+C** to stop playback early. This playback rate controls visualization, not acquisition-time calibration.

## Run the reference example

After initializing ImageJ-MATLAB, run:

```matlab
matlab_trackmate
```

This example uses different settings from the batch script: LoG detection with radius 2.5, a spot-quality filter above 50, Sparse LAP tracking with splitting and merging enabled, and a track-displacement filter above 10. It displays results but does not save batch XML files.

## Troubleshooting

- **`ij` or `fiji.plugin.trackmate` classes cannot be found:** Check the ImageJ-MATLAB installation and initialize `ImageJ` in the current MATLAB session.
- **`AdvancedKalmanTrackerFactory` cannot be loaded:** Check that your Fiji installation provides the intended tracker. As noted in the script, save a working configuration from the TrackMate GUI, inspect its tracker class/settings, and update the import and factory assignment if needed.
- **No AVI files found:** Check every configured folder and the recursive `*.avi` search.
- **A video cannot be opened:** Try opening it directly in Fiji and check that its AVI encoding is supported.
- **No detections or tracks:** Check foreground intensity, channel selection, search distances, and the displacement filter on a representative video.
- **`checkInput` or processing errors:** Read the printed TrackMate error message and compare the settings with those accepted by your installed tracker.

## References

- [TrackMate documentation](https://imagej.net/plugins/trackmate/)
- [Using TrackMate from MATLAB](https://imagej.net/plugins/trackmate/scripting/using-from-matlab)
- [ImageJ-MATLAB integration](https://imagej.net/scripting/matlab)

The reference script follows the example workflow in the TrackMate MATLAB documentation.
