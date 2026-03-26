# Nowcasting-Mexico-s-GDP-Using-Traditional-and-Machine-Learning-Models
This repository contains the code and paper for a research project comparing traditional and machine learning nowcasting methods applied to Mexico's GDP. The project was completed as part of the MSc Economics program at the University of Edinburgh (April 2025). Authors: Alfonso Sanchez Mayes, Andras Podolyak, Patricia Farmosi, Samuel Grundy-Tenn

Overview:
Nowcasting, predicting macroeconomic variables in the present or near future, is well-developed in rich countries but largely absent in emerging economies. This paper is, to our knowledge, the first to apply Mixed Data Sampling (MIDAS) and modern machine learning methods to nowcast Mexico's GDP using mixed-frequency data.
We compare five model families against a Bridge Equation (BE) benchmark, evaluated using Mean Squared Prediction Error (MSPE) and the Diebold-Mariano test (D-M test) across 58 out-of-sample GDP predictions from 2011 to 2024.
Key result: MIDAS outperformed all other models, achieving 58% lower MSPE than the Bridge Equation benchmark. Elastic Net came in second at 29% better than the benchmark.

Models:

Model           |   MSPE   |   D-M test  |
Bridge Equation |  0.1521  |  Benchamrk  |
MIDAS (Best)    |  0.0632  |      58%    |
Elastic Net     |  0.108   |      29%    |
SVR             |  0.3332  |     -119%   |
Random Forest   |  7.7130  |     -4900%  |

Two ensemble methods (uniform and regression-based weighting) were also tested but did not improve on the best individual MIDAS model.


Repository Structure:
nowcasting-mexico-gdp/
├── README.md
├── paper/
│   └── Nowcasting_Mexico_GDP.pdf       # Full paper
├── code/
│   ├── MIDAS.R                         # MIDAS models (R)
│   └── Bridge_Equation.do              # Bridge Equation models (Stata)
└── data/
    └── README_data.md                  # Data sources and download instructions

Data
The data is included in this repository, and is freely available from the following public sources:

Mexico GDP (PCFPY): INEGI — quarterly, from Q1 1993
U.S. macroeconomic indicators: FRED (Federal Reserve Economic Data) — monthly and weekly series including unemployment claims, industrial production, car sales, and more
Mexico macroeconomic indicators: Banxico (Banco de México) — monthly series including IGAE, private consumption, industrial activity, remittances, exchange rate, and Cetes

The dataset includes quarterly, monthly, and weekly indicators, requiring mixed-frequency handling. The ragged edge is addressed via vertical realignment (Altissimo et al., 2010). Missing tail values are extrapolated using autoregressive models.
Once downloaded, organize the data into an Excel file (Project - Data.xlsx) with three sheets: Quarter, Monthly, and Weekly. For the Stata Bridge Equation code, a .dta file is required (total_aggregated_variables_final_set.dta).
