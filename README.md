# Health data science projects

Work from a Master of Health Data Science, covering clinical prediction
modelling, survival analysis and interactive visualisation across Python and R.

## Clinical prediction

**`breast_cancer_classification.ipynb`**

Regularised logistic regression against a feedforward neural network on nucleus
morphology from fine needle aspiration biopsies, using the Wisconsin Diagnostic
Breast Cancer dataset.

The evaluation is framed around the sensitivity and specificity trade-off rather
than accuracy. With 63 percent of cases benign, a model that predicted every case
benign would score 63 percent accuracy while missing every malignant tumour, so
accuracy alone is close to meaningless here. Recall on the malignant class is
treated as the primary criterion, since a false negative means a cancer goes
untreated.

The notebook ends on a deployment argument: the neural network scored slightly
higher on malignant recall, but the difference came down to a single patient on a
57 case test set, and logistic regression is preferred anyway because its
coefficients can be inspected and explained to a clinician.

## Survival analysis

**`ed_modeling.ipynb`**

ICU patient data modelled two ways for two different purposes.

The explanatory model uses logistic regression on in-hospital mortality, and
deliberately excludes SAPS1 because that composite score already incorporates age
and thirteen physiological variables, which would mask the individual effects the
model is meant to explain. The predictive model reverses that choice, using a Cox
proportional hazards model on survival time where SAPS1 is preferred precisely
because a parsimonious composite works well when discrimination is the goal.

## Visualisation

**`visualization/hf_eda.qmd`**

Exploratory analysis of the Zigong heart failure cohort, using small multiples to
contrast subgroups.

**`visualization/hf_shiny/`**

Shiny application adding interactivity to those charts, with variable selection,
subset filtering and axis controls. Plot functions are separated into `plots.R`
so the app logic stays readable.

**`visualization/dreamt_project/`**

Scrollytelling piece examining whether heart rate and electrodermal activity can
distinguish psychological stress from physical exertion, built on the Wearable
Device Dataset from PhysioNet.

`data_preparation.md` documents how 36 participants of raw sensor recordings at
three sampling rates became four analysis tables, including the decisions taken
and the verification checks run. `build_data.ipynb` implements it.

Group project with Alison Doan, Christina-Giovanna Isolabella and Vaishnavi Dalvi.

## Data

No datasets are included. Each project documents its source. The wearables data
is openly available from PhysioNet, the breast cancer data ships with
scikit-learn, and the clinical datasets are not publicly redistributable.

## Stack

Python (`scikit-learn`, `keras`, `pandas`, `seaborn`) and R (`tidyverse`,
`shiny`, `plotly`, `quarto`, `survival`).
