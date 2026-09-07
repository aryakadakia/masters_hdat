# Source
The original data is from the Wearable Device Dataset from Induced Stress and Structured Exercise Sessionsproject on PhysioNet
(https://physionet.org/content/wearable-device-dataset/1.0.1/).

# How to reproduce the data used in this analysis

Considering that raw data is not committed to the repository, please follow these steps to reproduce the data used in the analysis.

1) Download and unzip the raw data folder from PhysioNet (`wearable-device-dataset-from-induced-stress-and-structured-exercise-sessions-1.0.1.zip`)
2) Clone the assignment repository as a sibling directory to the raw data folder.
3) Open the Python notebook in this assignment repository (`build_data.ipynb`). 
4) Change the paths in the first block - 
  - `raw_data_folder` - the path to the raw data folder downloaded from PhysioNet
  - `dataset_path` - the path to `Wearable_Dataset/` inside the raw data folder
  - `stress_level_v1_path` - the path to `Stress_Level_v1.csv` inside the raw data folder
  - `stress_level_v2_path` - the path to`Stress_Level_v2.csv` inside the raw data folder
5) Run the notebook to write four parquet files (`signals_1hz.parquet`, `events.parquet`, `participants.parquet`, `self_report.parquet`)
    into a `built/` folder created as a sibling directory.
6) This assignment's output (`setup.R`, `scrollytelling.qmd`, `eda.Rmd`, and `app.R`) reads these parquet files from `../built/` so
   confirm that the layout looks like:

```
parent/
├─ <this-repo>/       (setup.R, scrollytelling.qmd, eda.Rmd, app.R, ...)
└─ built/             (signals_1hz.parquet, events.parquet, participants.parquet, self_report.parquet)
└─ wearable-device-dataset-from-induced-stress-and-structured-exercise-sessions-1.0.1/   (the raw data folder from PhysioNet)
```
7) Before running the files, open the `.Rproj` and either install packages listed in `setup.R` or run `renv::restore()` in the console
   to install the exact package versions used in this analysis (recorded in `renv.lock`). The closeread Quarto extension is already committed
   to this repository (in `_extensions/`), so no separate installation should be needed. However, if rendering shows that the extension is missing, 
   please run `quarto add closeread` in the terminal of the repo folder.
8) Render `scrollytelling.qmd` and run `app.R` to review our final output.

## Note on the animation
`scene2_aerobic.gif` is committed to the repository so that rendering `scrollytelling.qmd` works directly using the provided gif.
It is not rebuilt when you click 'Render', as its code block (`{r scene2}`) is set to `eval: false` to keep rendering fast and to avoid
a gganimate/knitr rendering issue. To regenerate the gif yourself, run the `scene2` code block in `scrollytelling.qmd` manually before
rendering.
   
# References
Mastering Shiny — https://mastering-shiny.org
R for Data Science (2e) — https://r4ds.hadley.nz

# Package Documentation
dplyr - https://dplyr.tidyverse.org/articles/programming.html
ggplot2 - https://ggplot2.tidyverse.org/reference/
shiny - https://shiny.posit.co/r/reference/shiny/latest/
scales - https://scales.r-lib.org/reference/label_percent.html
forcats - https://forcats.tidyverse.org/reference/
stringr - https://stringr.tidyverse.org/reference/
gganimate - https://gganimate.com/reference/index.html; https://gganimate.com/reference/renderers.html
closeread - https://closeread.dev/guide/
patchwork - https://www.rdocumentation.org/packages/patchwork/versions/0.0.1
arrow - https://www.rdocumentation.org/packages/arrow/versions/8.0.0
knitr - https://www.rdocumentation.org/packages/knitr/versions/1.51
naniar - https://naniar.njtierney.com/
plotly - https://plotly.com/python/
