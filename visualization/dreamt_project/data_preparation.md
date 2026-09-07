------------------------------------------------------------------------

# Data preparation

This document records how the raw recordings were converted into four tables, the decisions taken along the way, and the various verification checks.

------------------------------------------------------------------------

# 1. The data and the prepared tables

## 1.1 Source and cohort

The original data is from the *Wearable Device Dataset from Induced Stress and Structured Exercise Sessions* project on PhysioNet (<https://physionet.org/content/wearable-device-dataset/1.0.1/>).

Thirty six volunteers wore an Empatica E4 wristband while completing laboratory protocols designed to induce either psychological stress or physical exertion. Eighteen participants (**S01–S18**) completed the original protocols and a later group of eighteen (**f01–f18**) completed revised versions.

Not every participant did every protocol -

| Condition | Participants | Notes                           |
|-----------|--------------|---------------------------------|
| Stress    | 36           | S01–S18 and f01–f18             |
| Aerobic   | 30           | S01–S18 (minus S12) and f01–f13 |
| Anaerobic | 31           | S01–S18 and f01–f13             |

Participants f14–f18 completed only the stress protocol. **Thirty participants completed all three conditions**.

## 1.2 Signals used

The E4 records several signals at different rates. Three are used in the analysis:

| Signal  | Rate  | Unit   | Measures                                  |
|---------|-------|--------|-------------------------------------------|
| **HR**  | 1 Hz  | bpm    | Heart rate derived from the pulse sensor  |
| **EDA** | 4 Hz  | µS     | Electrodermal activity (skin conductance) |
| **ACC** | 32 Hz | 1/64 g | Three-axis acceleration (movement)        |

Three signals are **excluded from the prepared data**:

- **BVP** (64 Hz raw pulse waveform): we already planned on using heart rate, which Empatica derives from this raw signal.
- **IBI** (irregular inter-beat intervals): the analysis did not include heart-rate variability.
- **TEMP** (4 Hz skin temperature): excluded for data quality reasons.

Alongside the sensors, the wristband has a **physical button** that the researcher pressed to mark the boundary between protocol stages. These presses (in `tags.csv`) make it possible to know which task was running at any moment and was helpful to label the stages.

## 1.3 Conditions

**Aerobic**: continuous cycling with cadence rising in steps, stages labelled by target cadence (`rpm_60` through `rpm_110`) between a warm-up and cool-down.

**Anaerobic**: short maximal sprints separated by long recoveries (v1: 3 × 30 s; v2: 4 × 45 s).

**Stress**: various cognitive tasks separated by rests, with a self-reported stress rating (1–10) per block.

## 1.4 The prepared tables

The raw data included 97 folders (one per participant per condition). It was therefore converted into four combined tables and saved as **parquet** files. All analysis uses these tables instead of the raw data.

| Table | Each row is | Key columns |
|------------------------|------------------------|------------------------|
| `participants` | one participant in one condition | subject, condition, version, demographics |
| `events` | one protocol stage in one session | subject, condition, version, phase, t_start, t_end, duration |
| `self_report` | one stress rating for one stage | subject, version, phase, rating |
| `signals_1hz` | one signal's value at one second | subject, condition, version, signal, t, value, phase, t_rel |

`signals_1hz` contains **HR, EDA and a derived ACC measure**. Each is averaged to one value per second.

Two derived columns provide the stage labels:

- **`phase`** - which protocol stage was running that second. `NA` is used for seconds outside any labelled stage.
- **`t_rel`** - seconds since that stage began, so participants who reached a stage at different times can be lined up from the moment each stage started.

------------------------------------------------------------------------

# 2. How the tables were built

The data preparation was done in Google Colab. The authors provided a Python notebook (`Wearable_Dataset.ipynb`) alongside the raw data that reads the Empatica files and reconstructs each signal's timeline. Four of their functions are used for this preparation - `read_signals()`, `moving_average()`, `create_df_array()` and `time_abs_()` - which handle the Empatica file format, reconstruct each signal's timeline from its recorded start time and sampling rate, convert the button-press times to seconds since the session started, and collapse the three accelerometer axes into a single smoothed per-second movement value.

Using their reader ensures the files are parsed as the authors intended. However, this reader only returned signals nested per participant, whereas comparing participants and joining physiology to stage labels needed one flat table. As we were interested in within-subject analysis, we used Claude Opus 4.8 to write code that converted the nested, multi-rate signal output into a single tidy table on a common one-second grid, with protocol stages and self-report ratings joined on.

## Step 1: Flatten the nested output into a tidy table

The initial reader returned nested dictionaries, where `signal_data['STRESS']['S01']['EDA']` is an array of values and `time_data['STRESS']['S01']['EDA']` holds the matching timestamps. This was convenient for plotting a single person but not for filtering or grouping across participants.

First, we stepped through every condition, participant and signal in the nested dictionaries and created one row per reading, with columns for subject, condition, part, version, signal, time and value. Folder names are split at the same time (`S11_a` → subject `S11`, part `a`), and subjects beginning `S` are identified as version 1 while those beginning `f` are version 2. Moreover, ACC data is passed through `moving_average()`, which already returns one value per second, so its timestamps are simply 0, 1, 2 and so on. Heart rate timestamps have 10 seconds added as well, because HR.csv begins ten seconds after the other signals.

## Step 2: Put every signal on a common 1s grid

The signals arrive at different rates, so in any given second there are four EDA readings but only one HR reading. Thus, we round every timestamp down to a whole second and average all readings within it (for example, readings at 12.25 s, 12.5 s and 12.75 s are averaged to one value for second 12). One hertz was chosen because it is the rate of the slowest signal (HR). Signals within a session do not all end on the same second, so shorter ones have their final value repeated until they reach the same end as the longest.

## Step 3: Label the protocol stages

`tags.csv` gives button-press times but no labels. The protocol diagrams supplied with the dataset resolve this by showing each protocol's stages as ordered blocks with numbered circles above the boundaries, where the circles are the button presses. These diagrams were embedded as attachments inside the authors' notebook and were extracted to image files to be read (the resulting diagrams can be seen in our notebook `build_data.ipynb`). This mapping is recorded in a lookup table (`PHASE_MAP`), with one line per stage per condition per version. Some tag numbers are skipped because those presses mark self-report ratings rather than stage boundaries, and the mapping accounts for them by reading each stage's exact start and end tag from the diagram.

For each session the code records a row per stage with its start, end and duration, which forms the `events` table.

## Step 4: Join and output data

The constraints file recorded that S02's stress recording duplicates from ACC row 49,545, BVP row 99,091 and EDA row 6,195. Each divided by its sampling rate gives \~1548s, which is the same moment. Everything after 1548s is therefore removed as it is a duplicate copy of the earlier recording rather than new data.

Next, for each of the 832 `events` rows, every `signals_1hz` row in the same session whose timestamp falls within that stage's window is stamped with the stage name and `t_rel` (i.e., its time minus the stage start). Readings outside any labelled stage are left NA, which is why phase coverage sits at 79.2% rather than 100%.

Each participant's demographics from `subject-info.csv` are also attached to their rows in the table.

`Stress_Level_v1.csv` and `Stress_Level_v2.csv` that are provided wide (one row per participant and one column per stage) are then pivoted long, and the column headings are mapped to the same stage names used in `events`. This way, each rating lines up with the signal readings from the same stage.

Lastly, the four prepared tables are saved as parquet files into a folder `Group/built/`.

------------------------------------------------------------------------

# 4. Checks, decisions, and considerations

## 4.1 Verification checks

| What was checked | Changed built data | Result |
|-----------------------|------------------|-------------------------------|
| Value and timestamp array lengths | No | 0 mismatches across all sessions and signals. |
| 1 Hz resampling | No | The one-second averaging was re-done separately in R and gave the same values as the saved data. |
| Stage labels applied correctly | No | Each second of signal was matched to at most one stage. None were counted twice where two stages meet and the time since each stage began was correct. |
| Self-report stage names against `events` | No | All matched, so no rating was dropped when self-report was joined to the physiology. |
| Demographics merge | No | All 97 participant-condition rows matched, so no rows were lost. |
| S02 truncation | No | 0 rows remain past 1548s in the saved table. |
| Tag counts per session | No | Each matches the expected count or a documented issue, so no unexplained anomaly. |
| Signal start time | Yes | HR recordings begin exactly 10.0 s after the other signals in all 100 sessions, a known offset in how the device logs heart rate. This is corrected by adding 10 s to every HR timestamp. |
| Stage durations against the written protocol | Yes | Comparing measured stage durations against the dataset's written protocol caught one mapping error in anaerobic v2. The button presses had been paired in the wrong order, so each "sprint" accidentally included the recovery after it and measured about 190s instead of the intended 45s. Re-pairing the presses to the correct sprint boundaries aligned the durations with the protocol. |
| Aerobic v1 diagram against the written protocol | No | The diagram's printed stage times ("3:00"/"2:00") disagree with the written protocol and the measured durations, which agree with each other. Only the diagram's tag numbers (not the times) are used, so nothing in the built data is affected. |

## 4.2 Decisions

| Decision | Alternative | Reason |
|------------------------|------------------------|------------------------|
| Retain `version` as a covariate | Pool the two versions | Version 2 timing is looser (sprints run short, rests run long), which is consistent with its remote and group setting. |
| Exclude split parts `S11_b`, `S16_b` from stage labelling | Attempt to label them | When a session was saved in two files, the second file's first button press is not the start of the protocol but wherever recording resumed after the dropout. Since the stage labelling depends on knowing which press marks the start, these parts cannot be labelled reliably. They stay in `signals_1hz` as unlabelled signal. |
| Exclude `S11`, `S16`, `f14` from the session explorer | Show them with a caption | The unrecorded gap between their two files would draw a false continuous line. |
| Drop `pre_protocol` time | Treat it as baseline | Wristband time before the protocol began so it is not technically a stage and its length is not fixed. |
| Exclude TEMP from the built data | Retain it and screen downstream | 3,631 impossible readings up to 235°C. |
| Exclude BVP and IBI | Include at native rate | BVP is a 64 Hz waveform that would add tens of millions of rows and is never plotted directly. IBI is one irregular row per heartbeat, which does not fit a per-second grid cleanly. |
| Average to 1 Hz using the mean | Median | Conventional and preserves the sharp EDA responses. |
| Resample to 1 Hz | A higher rate | 1 Hz is the slowest retained signal. |
| Document data-quality issues rather than delete sessions | Delete affected sessions | Many issues affect only one signal, so the rest of the session is still usable. |

## 4.3 Considerations

**Participant constraints**

| Subject | Condition | Issue | Effect |
|------------------|------------------|------------------|------------------|
| S01 | Anaerobic | IBI file is empty | No effect as heart-rate variability data is not used |
| S02 | Stress | Duplicated recording | Truncated in the built data |
| f07 | Stress | Protection dock left on, which covered the pulse and temperature sensors | Only EDA and ACC are valid |
| f14 | Stress | Split recording | `f14_a` is baseline only; `f14_b` holds the rest of the session |
| S03 | Aerobic | Ended early, reached only 90 rpm | Usable but truncated |
| S07 | Aerobic | Ended early, reached only 95 rpm | Usable but truncated |
| S11 | Aerobic | Split recording | Part b unlabelled |
| S12 | Aerobic | Did not perform the protocol | No data exists |
| S06 | Anaerobic | Ended early, final sprint missing | Two of three sprints usable |
| S16 | Anaerobic | Split recording | Part b unlabelled |

**Tail padding does not affect the analysis.** When signals in a session end at slightly different seconds, resampling repeats the last value of the shorter ones so they all finish at the same point. This adds a small number of carried-forward rows (1,104, or 0.18%), all of which fall after the final labelled stage. Every scene and app view filters on phase, so none of these rows reach the analysis.

**Stage durations are approximate.** Boundaries come from a researcher pressing a button, so measured durations run a few seconds either side of the intended times. This is fine for cutting the signals into stages but should not be quoted as exact protocol timings.
