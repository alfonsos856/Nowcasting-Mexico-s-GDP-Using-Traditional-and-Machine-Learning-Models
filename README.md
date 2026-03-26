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

Note: I have only attached work for the sections that I worked in.

Data
The data is included in this repository, and is freely available from the following public sources:

Mexico GDP (PCFPY): INEGI — quarterly, from Q1 1993

U.S. macroeconomic indicators: FRED (Federal Reserve Economic Data) — monthly and weekly series including unemployment claims, industrial production, car sales, and more

Mexico macroeconomic indicators: Banxico (Banco de México) — monthly series including IGAE, private consumption, industrial activity, remittances, exchange rate, and Cetes

The dataset includes quarterly, monthly, and weekly indicators, requiring mixed-frequency handling. The ragged edge is addressed via vertical realignment (Altissimo et al., 2010). Missing tail values are extrapolated using autoregressive models.

Once downloaded, organize the data into an Excel file (Project - Data.xlsx) with three sheets: Quarter, Monthly, and Weekly. For the Stata Bridge Equation code, a .dta file is required (total_aggregated_variables_final_set.dta).

Key Methodological Notes

Mixed-frequency problem: MIDAS handles this natively using the Almon polynomial lag structure. Bridge Equations use time-averaging (vertical realignment).

Ragged edge: Addressed via vertical realignment following Altissimo et al. (2010). Missing tail observations are extrapolated using AR(3) or AR(12) models depending on frequency.

Model evaluation: All models are evaluated using expanding window out-of-sample cross-validation starting from observation 71, yielding 58 predictions from 2011 to 2024.

COVID period: Models are not explicitly adjusted for COVID, which accounts for a substantial share of prediction error across all specifications.

Paper
The full paper is available in the attached documents. It covers the literature review, data description, methodology, results, and conclusions in detail.

Citation

If you use this code or paper, please cite:

Sanchez Mayes, A., Podolyak, A., Farmosi, P., & Grundy-Tenn, S. (2025). Nowcasting Mexico's GDP using Mixed Frequency Data with Traditional and Machine Learning Methods. University of Edinburgh.
