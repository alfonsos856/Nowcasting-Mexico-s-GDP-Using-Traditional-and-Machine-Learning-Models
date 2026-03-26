#install.packages("MSwM")
library(dplyr)
library(tidyr)
library(readxl)
library(MSwM)
library("ggplot2")
library("tseries")
library("midasr")


setwd("YOUR_WORKING_DIRECTORY_HERE")
data_q <- read_excel("Project - Data.xlsx", sheet = "Quarter") %>% mutate_all(as.numeric)
data_m <- read_excel("Project - Data.xlsx", sheet = "Monthly") %>% mutate_all(as.numeric)
data_w <- read_excel("Project - Data.xlsx", sheet = "Weekly") %>% mutate_all(as.numeric)

data_q$Date <- seq(as.Date("1948-01-01"), by = "quarter", length.out = nrow(data_q))
data_m$Date <- seq(as.Date("1919-01-01"), by = "month", length.out = nrow(data_m))
data_w$Date <- seq(as.Date("1968-01-06"), by = "week", length.out = nrow(data_w))


# Add one more row manually before running the extrapolation
#############################################################################################extrapolating quarters
# Get the last date from the dataset
last_date_q <- max(data_q$Date, na.rm = TRUE)

# Calculate the next quarter's date
next_date_q <- seq(last_date_q, by = "quarter", length.out = 2)[2]

# Create a new row that matches the structure of data_q
new_row <- data_q[1, ]  # Copy the structure of the first row
new_row$Date <- next_date_q  # Set the next quarter's date
new_row$`US Private Consumption Expenditure (PCFPY)` <- NA  # Set the variable to NA

# Append the new row to the dataset
data_q <- rbind(data_q, new_row)

# Function for Extrapolation (One Step at a Time)
extrapolate_one_step_q<- function(data, var_name, steps_ahead = 3) {
  
  # Ensure the variable exists in the dataset
  if(!(var_name %in% colnames(data))) {
    cat("⚠️ Variable", var_name, "does not exist in the dataset. Skipping...\n")
    return(data)
  }
  
  # Loop through the steps (one at a time)
  for (h in 1:steps_ahead) {
    # Generate lag variables (L1, L2, L3) for the specified variable only
    data <- data %>%
      mutate(
        L1 = lag(data[[var_name]], 1),
        L2 = lag(data[[var_name]], 2),
        L3 = lag(data[[var_name]], 3)
      )
    
    # Check if there's enough data for regression
    available_data <- sum(!is.na(data[[var_name]]))
    
    if (available_data > 10) {
      # Run the autoregressive model (using L1, L2, L3 as regressors)
      ar_model <- lm(data[[var_name]] ~ L1 + L2 + L3, data = data, na.action = na.omit)
      
      # Predict missing values for this step (one step ahead)
      missing_data <- is.na(data[[var_name]])  # Identify rows with missing data
      data[[var_name]][missing_data] <- predict(ar_model, newdata = data[missing_data, ])  # Fill missing values
    } else {
      cat("⚠️ Skipping", var_name, "(Step", h, "): Not enough data for regression.\n")
    }
    
    # Drop temporary lag variables after each step to avoid interference
    data <- data %>% select(-L1, -L2, -L3)
  }
  
  return(data)
}

# Example usage for the specified variable "US Private Consumption Expenditure (PCFPY)"
data_q <- extrapolate_one_step_q(data_q, var_name = "US Private Consumption Expenditure (PCFPY)", steps_ahead = 3)
data_q <- extrapolate_one_step_q(data_q, var_name = "Total Retail Trade: Volume for Mexico (Growth Rate from Previous Period)", steps_ahead = 3)

####################################################################################################################################extrapolating months
# Get the last date from the dataset
last_date_m <- max(data_m$Date, na.rm = TRUE)

# Calculate the next quarter's date
next_date_m <- seq(last_date_m, by = "quarter", length.out = 2)[2]

# Create a new row that matches the structure of data_m
new_row <- data_m[1, ]  # Copy the structure of the first row
new_row$Date <- next_date_m  # Set the next month's date
new_row$`US Industral Production Index (Level)` <- NA  # Set the variable to NA

# Append the new row to the dataset
data_m <- rbind(data_m, new_row)

extrapolate_one_step_m <- function(data, var_name, steps_ahead = 3) {
  
  if (!(var_name %in% colnames(data))) {
    cat("⚠️ Variable", var_name, "does not exist in the dataset. Skipping...\n")
    return(data)
  }
  
  for (h in 1:steps_ahead) {
    
    # Create lag variables L1 to L12
    for (i in 1:12) {
      data[[paste0("L", i)]] <- dplyr::lag(data[[var_name]], i)
    }
    
    # Build formula
    lag_terms <- paste0("L", 1:12, collapse = " + ")
    formula_str <- paste0("`", var_name, "` ~ ", lag_terms)
    formula <- as.formula(formula_str)
    
    # Filter out rows with NA/Inf in any required column
    model_data <- data %>%
      filter(if_all(all_of(c(var_name, paste0("L", 1:12))), ~ is.finite(.)))
    
    if (nrow(model_data) > 20) {
      ar_model <- lm(formula, data = model_data)
      
      missing_rows <- which(is.na(data[[var_name]]))
      if (length(missing_rows) > 0) {
        preds <- predict(ar_model, newdata = data[missing_rows, ])
        data[[var_name]][missing_rows] <- preds
      }
      
    } else {
      cat("⚠️ Step", h, "-", var_name, ": Not enough usable data to fit AR(12).\n")
    }
    
    # Clean up lag variables
    data <- data %>% select(-matches("^L[0-9]+$"))
  }
  
  return(data)
}


library(dplyr)

# Original monthly level variable names
level_vars <- c(
  "Construction Industry Index (Levels)",
  "Commercial Real Estate Price Index (Levels)",
  "Exchange Rate US-Peso Levels",
  "US Industral Production Index (Level)",
  "Mining Production Index (Levels, * Last Obs were from a different site, not fully the same)"
)

# Custom clean names for renaming after transformation
clean_names <- c(
  "Construction Industry Index_PCFPY",
  "Commercial Real Estate Price Index_PCFPY",
  "Exchange Rate US-Peso_PCFPY",
  "US Industral Production Index_PCFPY",
  "Mining Production Index_PCFPY"
)

# Loop through and overwrite original vars with YoY growth, rename to PCFPY
for (i in seq_along(level_vars)) {
  var <- level_vars[i]
  new_var <- clean_names[i]
  
  data_m[[new_var]] <- 100 * (
    data_m[[var]] - lag(data_m[[var]], 12)
  ) / lag(data_m[[var]], 12)
  
  data_m[[var]] <- NULL  # remove original (Levels) column
}



# Example usage for the specified variable "US Private Consumption Expenditure (PCFPY)"
data_m <- extrapolate_one_step_m(data_m, var_name = "US Industral Production Index_PCFPY", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "U.S. Unemployment Rate", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "Total U.S. Car Sales (PCFPY)", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "Mexico Private Consumption (PCFPY)", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "Mexico Industrial Activity Index (PCFPY)", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "Construction Industry Index_PCFPY", steps_ahead = 19)
data_m<- extrapolate_one_step_m(data_m, var_name = "Cetes (Mexican T-Bills) 28 days, average monthly yield, in annual percentage", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "IGAE (INEGI's Global Economic Status Indicator, PCFPY)", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "Commercial Real Estate Price Index_PCFPY", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "Remittances (P.C.F.P.Y)", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "Mexico - US Total Net Trade (Exports - Imports, PCFPY)", steps_ahead = 3)
data_m<- extrapolate_one_step_m(data_m, var_name = "Exchange Rate US-Peso_PCFPY", steps_ahead = 4)
data_m<- extrapolate_one_step_m(data_m, var_name = "Mining Production Index_PCFPY", steps_ahead = 4)

####################################################################################################################################making weeks match the quarters

# Step 1: Filter quarterly data from 1994 onward
data_q <- data_q %>% filter(Date >= as.Date("1994-01-01"))
gdp <- data_q$`Mexico GDP (INEGI, PCFPY)`  # Replacing y with gdp
n_gdp <- length(gdp)

# Step 2: Filter weekly data from 1994 onward
US_Unem_Init_full <- data_w %>%
  filter(Date >= as.Date("1994-01-01")) %>%
  pull(`Unemployment Insurance Initial Claims (PCFPY)`)

US_Unem_Init <- US_Unem_Init_full[1:(n_gdp * 13)+7]

US_Unem_Cont_full <- data_w %>%
  filter(Date >= as.Date("1994-01-01")) %>%
  pull(`Unemployment Insurance Continued Claims (PCFPY)`)

US_Unem_Cont <- US_Unem_Cont_full[1:(n_gdp * 13)+7]

y <- data_q$`Mexico GDP (INEGI, PCFPY)`

################################################################################AIC weekly
start_values_list <- list(
  c(1, -0.5), 
  c(0.5, -0.2), 
  c(0.1, -0.1), 
  c(2, -1), 
  c(0.8, -0.3), 
  c(1, -1.0),
  c(1, -1.5),
  c(0.5, -0.8),
  c(0.75, -0.3),
  c(2, -0.5),
  c(0.8, -0.5), 
  c(0.6, -0.3), 
  c(1.2, -0.7), 
  c(1.5, -0.2), 
  c(1.3, -0.9)
)

# Initialize an empty data frame to store the AIC values and corresponding starting values for US_Unem_Init and US_Unem_Cont
aic_results <- data.frame(
  Start_Values_US_Unem_Init = character(0),
  Start_Values_US_Unem_Cont = character(0),
  AIC_US_Unem_Init = numeric(0),
  AIC_US_Unem_Cont = numeric(0)
)

# Loop through each set of starting values for US_Unem_Init
for (start_vals in start_values_list) {
  
  # Step 1: Fit the MIDAS regression model for gdp ~ US_Unem_Init
  tryCatch({
    model_US_Unem_Init <- midas_r(
      gdp ~ mls(US_Unem_Init, 0:12, 13, nealmon),  # Only US_Unem_Init is used for regression
      start = list(US_Unem_Init = start_vals)
    )
    
    # Extract the AIC value for US_Unem_Init
    aic_value_US_Unem_Init <- AIC(model_US_Unem_Init)
  }, error = function(e) {
    aic_value_US_Unem_Init <- NA  # If an error occurs, store NA for AIC
    print(paste("Error with start values for US_Unem_Init:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 2: Fit the MIDAS regression model for gdp ~ US_Unem_Cont (use the same start_vals for US_Unem_Cont)
  tryCatch({
    model_US_Unem_Cont <- midas_r(
      gdp ~ mls(US_Unem_Cont, 0:12, 13, nealmon),  # Only US_Unem_Cont is used for regression
      start = list(US_Unem_Cont = start_vals)  # Use the same start values for US_Unem_Cont
    )
    
    # Extract the AIC value for US_Unem_Cont
    aic_value_US_Unem_Cont <- AIC(model_US_Unem_Cont)
  }, error = function(e) {
    aic_value_US_Unem_Cont <- NA  # If an error occurs, store NA for AIC
    print(paste("Error with start values for US_Unem_Cont:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Store the results in the dataframe for both US_Unem_Init and US_Unem_Cont
  aic_results <- rbind(aic_results, data.frame(
    Start_Values_US_Unem_Init = paste(start_vals, collapse = ", "), 
    Start_Values_US_Unem_Cont = paste(start_vals, collapse = ", "),
    AIC_US_Unem_Init = aic_value_US_Unem_Init,
    AIC_US_Unem_Cont = aic_value_US_Unem_Cont
  ))
}

# Print the results
print(aic_results)

# Remove rows where AIC_X or AIC_Z is NA
aic_results_clean <- na.omit(aic_results)

# Find the best starting values for US_Unem_Init (lowest AIC_X)
best_model_US_Unem_Init <- aic_results_clean[which.min(aic_results_clean$AIC_US_Unem_Init), ]
cat("Best Model for US_Unem_Init:\n")
print(best_model_US_Unem_Init[, c("Start_Values_US_Unem_Init", "AIC_US_Unem_Init")])  # Print only the optimal US_Unem_Init and its AIC

# Find the best starting values for US_Unem_Cont (lowest AIC_Z)
best_model_US_Unem_Cont <- aic_results_clean[which.min(aic_results_clean$AIC_US_Unem_Cont), ]
cat("\nBest Model for US_Unem_Cont:\n")
print(best_model_US_Unem_Cont[, c("Start_Values_US_Unem_Cont", "AIC_US_Unem_Cont")])  # Print only the optimal US_Unem_Cont and its AIC

# 11. Fit the final model with the best starting values based on AIC
# Extract the best starting values for US_Unem_Init and US_Unem_Cont from the previous results
best_start_values_US_Unem_Init <- as.numeric(strsplit(as.character(best_model_US_Unem_Init$Start_Values_US_Unem_Init), ", ")[[1]])
best_start_values_US_Unem_Cont <- as.numeric(strsplit(as.character(best_model_US_Unem_Cont$Start_Values_US_Unem_Cont), ", ")[[1]])

US_Private_Cons_PCFPY <- data_q$`US Private Consumption Expenditure (PCFPY)`
US_GDP_Growth <- data_q$`US GDP Growth Rate`


###################################################################################AIC for monthly vars
# Initialize an empty data frame to store the AIC values and corresponding starting values for US_Unem_Init and US_Unem_Cont



data_m <- data_m%>% filter(Date >= as.Date("1994-01-01"))
US_Ind_Prod <- data_m$`US Industral Production Index_PCFPY` 
US_Unemp_Growth <- data_m$`U.S. Unemployment Rate` 
US_CarSales <- data_m$`Total U.S. Car Sales (PCFPY)` 
MX_PrivateCons <- data_m$`Mexico Private Consumption (PCFPY)` 
MX_Ind_Act <- data_m$`Mexico Industrial Activity Index (PCFPY)` 
MX_Construction <- data_m$`Construction Industry Index_PCFPY` 
Cetes <- data_m$`Cetes (Mexican T-Bills) 28 days, average monthly yield, in annual percentage` 
IGAE <- data_m$`IGAE (INEGI's Global Economic Status Indicator, PCFPY)` 
Comm_RealEstate <- data_m$`Commercial Real Estate Price Index_PCFPY` 
Remittances <- data_m$`Remittances (P.C.F.P.Y)` 
Trade <- data_m$`Mexico - US Total Net Trade (Exports - Imports, PCFPY)` 
ExchangeRate <- data_m$`Exchange Rate US-Peso_PCFPY` 
Min_Prod <- data_m$`Mining Production Index_PCFPY`

US_Ind_Prod_aligned <- US_Ind_Prod[1:(n_gdp * 3)]  
US_Unemp_aligned <- US_Unemp_Growth[1:(n_gdp * 3)]  
US_CarSales_aligned <- US_CarSales[1:(n_gdp * 3)]  
MX_PrivateCons_aligned <- MX_PrivateCons[1:(n_gdp * 3)]  
MX_Ind_Act_aligned <- MX_Ind_Act[1:(n_gdp * 3)]  
MX_Construction_aligned <- MX_Construction[1:(n_gdp * 3)]  
Cetes_aligned <- Cetes[1:(n_gdp * 3)]  
IGAE_aligned <- IGAE[1:(n_gdp * 3)]  
Comm_RealEstate_aligned <- Comm_RealEstate[1:(n_gdp * 3)]  
Remittances_aligned <- Remittances[1:(n_gdp * 3)]  
Trade_aligned <- Trade[1:(n_gdp * 3)]  
ExchangeRate_aligned <- ExchangeRate[1:(n_gdp * 3)]  
Min_Prod_aligned <- Min_Prod[1:(n_gdp * 3)]  



start_values_list_m <- list(
  c(1, -0.5),
  c(0.5, -0.2), 
  c(0.1, -0.1), 
  c(2, -1), 
  c(0.8, -0.3), 
  c(1, -1.0),
  c(1, -1.5),
  c(0.5, -0.8),
  c(0.75, -0.3),
  c(2, -0.5),
  c(0.8, -0.5), 
  c(0.6, -0.3), 
  c(1.2, -0.7), 
  c(1.5, -0.2), 
  c(1.3, -0.9)
)


aic_results_m<- data.frame(
  Start_Values_US_Ind_Prod = character(0),
  Start_Values_US_Unemp = character(0),
  Start_Values_US_CarSales = character(0),
  Start_Values_MX_PrivateCons = character(0),
  Start_Values_MX_Ind_Act = character(0),
  Start_Values_MX_Construction = character(0),
  Start_Values_Cetes = character(0),
  Start_Values_IGAE = character(0),
  Start_Values_Comm_RealEstate = character(0),
  Start_Values_Remittances = character(0),
  Start_Values_Trade = character(0),
  Start_Values_ExchangeRate = character(0),
  Start_Values_Min_Prod = character(0),
  
  AIC_US_Ind_Prod = numeric(0),
  AIC_US_Unemp = numeric(0),
  AIC_US_CarSales = numeric(0),
  AIC_MX_PrivateCons = numeric(0),
  AIC_MX_Ind_Act = numeric(0),
  AIC_MX_Construction = numeric(0),
  AIC_Cetes = numeric(0),
  AIC_IGAE = numeric(0),
  AIC_Comm_RealEstate = numeric(0),
  AIC_Remittances = numeric(0),
  AIC_Trade = numeric(0),
  AIC_ExchangeRate = numeric(0),
  AIC_Min_Prod = numeric(0)
)



# Loop through each set of start values and fit the model
for (start_vals in start_values_list_m) {
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_US_Ind_Prod <- midas_r(
      gdp ~ mls(US_Ind_Prod_aligned, 0:2, 3, nealmon),
      start = list(US_Ind_Prod_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_US_Ind_Prod <- AIC(model_US_Ind_Prod)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_US_Ind_Prod <- NA
    print(paste("Error with start values for US_Ind_Prod:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_US_Unemp <- midas_r(
      gdp ~ mls(US_Unemp_aligned, 0:2, 3, nealmon),
      start = list(US_Unemp_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_US_Unemp <- AIC(model_US_Unemp)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_US_Unemp <- NA
    print(paste("Error with start values for US_Unemp:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_US_CarSales <- midas_r(
      gdp ~ mls(US_CarSales_aligned, 0:2, 3, nealmon),
      start = list(US_CarSales_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_US_CarSales <- AIC(model_US_CarSales)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_US_CarSales <- NA
    print(paste("Error with start values for US_CarSales:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_MX_PrivateCons <- midas_r(
      gdp ~ mls(MX_PrivateCons_aligned, 0:2, 3, nealmon),
      start = list(MX_PrivateCons_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_MX_PrivateCons <- AIC(model_MX_PrivateCons)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_MX_PrivateCons <- NA
    print(paste("Error with start values for MX_PrivateCons:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_MX_Ind_Act <- midas_r(
      gdp ~ mls(MX_Ind_Act_aligned, 0:2, 3, nealmon),
      start = list(MX_Ind_Act_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_MX_Ind_Act <- AIC(model_MX_Ind_Act)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_MX_Ind_Act <- NA
    print(paste("Error with start values for MX_Ind_Act:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_MX_Construction <- midas_r(
      gdp ~ mls(MX_Construction_aligned, 0:2, 3, nealmon),
      start = list(MX_Construction_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_MX_Construction <- AIC(model_MX_Construction)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_MX_Construction <- NA
    print(paste("Error with start values for MX_Construction:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_Cetes <- midas_r(
      gdp ~ mls(Cetes_aligned, 0:2, 3, nealmon),
      start = list(Cetes_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_Cetes <- AIC(model_Cetes)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_Cetes <- NA
    print(paste("Error with start values for Cetes:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_IGAE <- midas_r(
      gdp ~ mls(IGAE_aligned, 0:2, 3, nealmon),
      start = list(IGAE_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_IGAE <- AIC(model_IGAE)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_IGAE <- NA
    print(paste("Error with start values for IGAE:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_Comm_RealEstate <- midas_r(
      gdp ~ mls(Comm_RealEstate_aligned, 0:2, 3, nealmon),
      start = list(Comm_RealEstate_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_Comm_RealEstate <- AIC(model_Comm_RealEstate)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_Comm_RealEstate <- NA
    print(paste("Error with start values for Comm_RealEstate:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_Remittances <- midas_r(
      gdp ~ mls(Remittances_aligned, 0:2, 3, nealmon),
      start = list(Remittances_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_Remittances <- AIC(model_Remittances)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_Remittances <- NA
    print(paste("Error with start values for Remittances:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_Trade <- midas_r(
      gdp ~ mls(Trade_aligned, 0:2, 3, nealmon),
      start = list(Trade_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_Trade <- AIC(model_Trade)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_Trade <- NA
    print(paste("Error with start values for Trade:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_ExchangeRate <- midas_r(
      gdp ~ mls(ExchangeRate_aligned, 0:2, 3, nealmon),
      start = list(ExchangeRate_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_ExchangeRate <- AIC(model_ExchangeRate)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_ExchangeRate <- NA
    print(paste("Error with start values for ExchangeRate:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_Min_Prod <- midas_r(
      gdp ~ mls(Min_Prod_aligned, 0:2, 3, nealmon),
      start = list(Min_Prod_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_Min_Prod <- AIC(model_Min_Prod)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_Min_Prod <- NA
    print(paste("Error with start values for Min_Prod:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 2: Store the results in the dataframe for US_Ind_Prod
  aic_results_m <- rbind(aic_results_m, data.frame(
    Start_Values_US_Ind_Prod = paste(start_vals, collapse = ", "),
    AIC_US_Ind_Prod = aic_value_US_Ind_Prod
  ))
}

# Print the AIC results
print(aic_results_m)



# Initialize an empty data frame to store the AIC values and corresponding starting values for US_Ind_Prod
aic_results_m <- data.frame(
  Start_Values_US_Ind_Prod = character(0),
  AIC_US_Ind_Prod = numeric(0)
)


# Loop through each set of start values and fit the model
for (start_vals in start_values_list_m) {
  
  # Step 1: Check for missing values in US_Ind_Prod and handle them
  tryCatch({
    # Fit the MIDAS model for the current set of start values
    model_US_Ind_Prod <- midas_r(
      gdp ~ mls(US_Ind_Prod_aligned, 0:2, 3, nealmon),
      start = list(US_Ind_Prod_aligned = start_vals)
    )
    
    # Extract the AIC value for US_Ind_Prod
    aic_value_US_Ind_Prod <- AIC(model_US_Ind_Prod)
    
  }, error = function(e) {
    # If an error occurs, set AIC to NA and print the error message
    aic_value_US_Ind_Prod <- NA
    print(paste("Error with start values for US_Ind_Prod:", paste(start_vals, collapse = ", "), "Error:", e$message))
  })
  
  # Step 2: Store the results in the dataframe for US_Ind_Prod
  aic_results_m <- rbind(aic_results_m, data.frame(
    Start_Values_US_Ind_Prod = paste(start_vals, collapse = ", "),
    Start_Values_US_Unemp = paste(start_vals, collapse = ", "),
    Start_Values_US_CarSales = paste(start_vals, collapse = ", "),
    Start_Values_MX_PrivateCons = paste(start_vals, collapse = ", "),
    Start_Values_MX_Ind_Act = paste(start_vals, collapse = ", "),
    Start_Values_MX_Construction = paste(start_vals, collapse = ", "),
    Start_Values_Cetes = paste(start_vals, collapse = ", "),
    Start_Values_IGAE = paste(start_vals, collapse = ", "),
    Start_Values_Comm_RealEstate = paste(start_vals, collapse = ", "),
    Start_Values_Remittances = paste(start_vals, collapse = ", "),
    Start_Values_Trade = paste(start_vals, collapse = ", "),
    Start_Values_ExchangeRate = paste(start_vals, collapse = ", "),
    Start_Values_Min_Prod = paste(start_vals, collapse = ", "),
    AIC_US_Ind_Prod = aic_value_US_Ind_Prod,
    AIC_US_Unemp = aic_value_US_Unemp,
    AIC_US_CarSales = aic_value_US_CarSales,
    AIC_MX_PrivateCons = aic_value_MX_PrivateCons,
    AIC_MX_Ind_Act = aic_value_MX_Ind_Act,
    AIC_MX_Construction = aic_value_MX_Construction,
    AIC_Cetes = aic_value_Cetes,
    AIC_IGAE = aic_value_IGAE,
    AIC_Comm_RealEstate = aic_value_Comm_RealEstate,
    AIC_Remittances = aic_value_Remittances,
    AIC_Trade = aic_value_Trade,
    AIC_ExchangeRate = aic_value_ExchangeRate,
    AIC_Min_Prod = aic_value_Min_Prod
  ))
}

# Print the AIC results
print(aic_results_m)

# Clean the AIC results by removing rows where any AIC value is NA
aic_results_m_clean <- na.omit(aic_results_m)

# Find the best starting values for each variable (lowest AIC)
best_model_US_Ind_Prod <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_US_Ind_Prod), ]
cat("Best Model for US_Ind_Prod:\n")
print(best_model_US_Ind_Prod[, c("Start_Values_US_Ind_Prod", "AIC_US_Ind_Prod")])  # Print only the optimal US_Ind_Prod and its AIC

best_model_US_Unemp <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_US_Unemp), ]
cat("\nBest Model for US_Unemp:\n")
print(best_model_US_Unemp[, c("Start_Values_US_Unemp", "AIC_US_Unemp")])  # Print only the optimal US_Unemp and its AIC

best_model_US_CarSales <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_US_CarSales), ]
cat("\nBest Model for US_CarSales:\n")
print(best_model_US_CarSales[, c("Start_Values_US_CarSales", "AIC_US_CarSales")])  # Print only the optimal US_CarSales and its AIC

best_model_MX_PrivateCons <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_MX_PrivateCons), ]
cat("\nBest Model for MX_PrivateCons:\n")
print(best_model_MX_PrivateCons[, c("Start_Values_MX_PrivateCons", "AIC_MX_PrivateCons")])  # Print only the optimal MX_PrivateCons and its AIC

best_model_MX_Ind_Act <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_MX_Ind_Act), ]
cat("\nBest Model for MX_Ind_Act:\n")
print(best_model_MX_Ind_Act[, c("Start_Values_MX_Ind_Act", "AIC_MX_Ind_Act")])  # Print only the optimal MX_Ind_Act and its AIC

best_model_MX_Construction <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_MX_Construction), ]
cat("\nBest Model for MX_Construction:\n")
print(best_model_MX_Construction[, c("Start_Values_MX_Construction", "AIC_MX_Construction")])  # Print only the optimal MX_Construction and its AIC

best_model_Cetes <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_Cetes), ]
cat("\nBest Model for Cetes:\n")
print(best_model_Cetes[, c("Start_Values_Cetes", "AIC_Cetes")])  # Print only the optimal Cetes and its AIC

best_model_IGAE <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_IGAE), ]
cat("\nBest Model for IGAE:\n")
print(best_model_IGAE[, c("Start_Values_IGAE", "AIC_IGAE")])  # Print only the optimal IGAE and its AIC

best_model_Comm_RealEstate <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_Comm_RealEstate), ]
cat("\nBest Model for Comm_RealEstate:\n")
print(best_model_Comm_RealEstate[, c("Start_Values_Comm_RealEstate", "AIC_Comm_RealEstate")])  # Print only the optimal Comm_RealEstate and its AIC

best_model_Remittances <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_Remittances), ]
cat("\nBest Model for Remittances:\n")
print(best_model_Remittances[, c("Start_Values_Remittances", "AIC_Remittances")])  # Print only the optimal Remittances and its AIC

best_model_Trade <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_Trade), ]
cat("\nBest Model for Trade:\n")
print(best_model_Trade[, c("Start_Values_Trade", "AIC_Trade")])  # Print only the optimal Trade and its AIC

best_model_ExchangeRate <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_ExchangeRate), ]
cat("\nBest Model for ExchangeRate:\n")
print(best_model_ExchangeRate[, c("Start_Values_ExchangeRate", "AIC_ExchangeRate")])  # Print only the optimal ExchangeRate and its AIC

best_model_Min_Prod <- aic_results_m_clean[which.min(aic_results_m_clean$AIC_Min_Prod), ]
cat("\nBest Model for Min_Prod:\n")
print(best_model_Min_Prod[, c("Start_Values_Min_Prod", "AIC_Min_Prod")])  # Print only the optimal Min_Prod and its AIC

# Extract the best starting values for each variable from the previous results
best_start_values_US_Ind_Prod <- as.numeric(strsplit(as.character(best_model_US_Ind_Prod$Start_Values_US_Ind_Prod), ", ")[[1]])
best_start_values_US_Unemp <- as.numeric(strsplit(as.character(best_model_US_Unemp$Start_Values_US_Unemp), ", ")[[1]])
best_start_values_US_CarSales <- as.numeric(strsplit(as.character(best_model_US_CarSales$Start_Values_US_CarSales), ", ")[[1]])
best_start_values_MX_PrivateCons <- as.numeric(strsplit(as.character(best_model_MX_PrivateCons$Start_Values_MX_PrivateCons), ", ")[[1]])
best_start_values_MX_Ind_Act <- as.numeric(strsplit(as.character(best_model_MX_Ind_Act$Start_Values_MX_Ind_Act), ", ")[[1]])
best_start_values_MX_Construction <- as.numeric(strsplit(as.character(best_model_MX_Construction$Start_Values_MX_Construction), ", ")[[1]])
best_start_values_Cetes <- as.numeric(strsplit(as.character(best_model_Cetes$Start_Values_Cetes), ", ")[[1]])
best_start_values_IGAE <- as.numeric(strsplit(as.character(best_model_IGAE$Start_Values_IGAE), ", ")[[1]])
best_start_values_Comm_RealEstate <- as.numeric(strsplit(as.character(best_model_Comm_RealEstate$Start_Values_Comm_RealEstate), ", ")[[1]])
best_start_values_Remittances <- as.numeric(strsplit(as.character(best_model_Remittances$Start_Values_Remittances), ", ")[[1]])
best_start_values_Trade <- as.numeric(strsplit(as.character(best_model_Trade$Start_Values_Trade), ", ")[[1]])
best_start_values_ExchangeRate <- as.numeric(strsplit(as.character(best_model_ExchangeRate$Start_Values_ExchangeRate), ", ")[[1]])
best_start_values_Min_Prod <- as.numeric(strsplit(as.character(best_model_Min_Prod$Start_Values_Min_Prod), ", ")[[1]])


US_Private_Cons_PCFPY <- data_q$`US Private Consumption Expenditure (PCFPY)`
US_GDP_Growth <- data_q$`US GDP Growth Rate`
MX_retail <- data_q$`Total Retail Trade: Volume for Mexico (Growth Rate from Previous Period)`

# Assuming 'data_q' is your quarters data and 'Date' is the column for the quarter dates
data_q$Date <- as.Date(data_q$Date)  # Ensure the 'Date' column is in Date format

# Define the start and end of the COVID period
covid_start_date <- as.Date("2020-03-01")  # Start of COVID (March 2020)
covid_end_date <- as.Date("2022-05-01")  # End of COVID (May 1, 2022)

# Create the COVID dummy variable based on the length of GDP
data_q$COVID_Dummy <- 0  # Start with 0 for all observations

# Apply the condition where Date is within the COVID period
data_q$COVID_Dummy[data_q$Date >= covid_start_date & data_q$Date <= covid_end_date] <- 1

# Ensure the length of COVID_Dummy matches the length of GDP (Mexico GDP)
n_gdp <- length(data_q$`Mexico GDP (INEGI, PCFPY)`)

# Trim COVID_Dummy to match the length of GDP (up to the nth observation)
COVID_Dummy <- data_q$`COVID_Dummy`[8:124]




final_model_MIDAS1 <- midas_r(
  gdp ~ mls(US_Unem_Init, 0:12, 13, nealmon) + mls(US_Unem_Cont, 0:12, 13, nealmon) + US_Private_Cons_PCFPY + US_GDP_Growth + mls(US_CarSales_aligned, 0:2,3, nealmon) + mls(MX_PrivateCons_aligned, 0:2, 3, nealmon) + mls(MX_Ind_Act_aligned, 0:2, 3, nealmon) + mls(MX_Construction_aligned, 0:2, 3, nealmon) + mls(US_Ind_Prod_aligned, 0:2, 3, nealmon) + mls(IGAE_aligned, 0:2, 3, nealmon),
  start = list(US_Unem_Init = best_start_values_US_Unem_Init, US_Unem_Cont = best_start_values_US_Unem_Cont, US_CarSales_aligned = best_start_values_US_CarSales, MX_PrivateCons_aligned = best_start_values_MX_PrivateCons, MX_Ind_Act_aligned = best_start_values_MX_Ind_Act, 
               MX_Construction_aligned = best_start_values_MX_Construction, US_Ind_Prod_aligned = best_start_values_US_Ind_Prod, IGAE_aligned = best_start_values_IGAE)  # Use the best starting values for both US_Unem_Init and US_Unem_Cont
)

final_model_MIDAS2 <- midas_r(
  gdp ~ mls(US_Unem_Init, 0:12, 13, nealmon) + mls(US_Unem_Cont, 0:12, 13, nealmon) + US_Private_Cons_PCFPY + US_GDP_Growth +  MX_retail + mls(US_CarSales_aligned, 0:2,3, nealmon)
  + mls(US_Unemp_aligned, 0:2, 3, nealmon) + mls(MX_PrivateCons_aligned, 0:2, 3, nealmon) + mls(MX_Ind_Act_aligned, 0:2, 3, nealmon) + mls(MX_Construction_aligned, 0:2, 3, nealmon)
  + mls(Min_Prod_aligned, 0:2, 3, nealmon) + mls(US_Ind_Prod_aligned, 0:2, 3, nealmon) + mls(IGAE_aligned, 0:2, 3, nealmon),
  start = list(US_Unem_Init = best_start_values_US_Unem_Init, US_Unem_Cont = best_start_values_US_Unem_Cont, US_CarSales_aligned = best_start_values_US_CarSales, 
               US_Unemp_aligned =  best_start_values_US_Unemp, MX_PrivateCons_aligned = best_start_values_MX_PrivateCons, MX_Ind_Act_aligned = best_start_values_MX_Ind_Act, 
               MX_Construction_aligned = best_start_values_MX_Construction, Min_Prod_aligned = best_start_values_Min_Prod, US_Ind_Prod_aligned = best_start_values_US_Ind_Prod,
               IGAE_aligned = best_start_values_IGAE)  # Use the best starting values for both US_Unem_Init and US_Unem_Cont
)


final_model_MIDAS3 <- midas_r(
  gdp ~ mls(US_Unem_Init, 0:12, 13, nealmon) + mls(US_Unem_Cont, 0:12, 13, nealmon) + US_Private_Cons_PCFPY + US_GDP_Growth +  MX_retail + mls(US_CarSales_aligned, 0:2,3, nealmon)
  + mls(US_Unemp_aligned, 0:2, 3, nealmon) + mls(MX_PrivateCons_aligned, 0:2, 3, nealmon) + mls(MX_Ind_Act_aligned, 0:2, 3, nealmon) + mls(MX_Construction_aligned, 0:2, 3, nealmon)
  + mls(Min_Prod_aligned, 0:2, 3, nealmon) + mls(US_Ind_Prod_aligned, 0:2, 3, nealmon) + mls(IGAE_aligned, 0:2, 3, nealmon) +mls(Cetes_aligned, 0:2, 3, nealmon) 
  + mls(Comm_RealEstate_aligned, 0:2, 3, nealmon) + mls(Remittances_aligned, 0:2, 3, nealmon) + mls(ExchangeRate_aligned, 0:2, 3, nealmon) + mls(Trade_aligned, 0:2, 3, nealmon),
  start = list(US_Unem_Init = best_start_values_US_Unem_Init, US_Unem_Cont = best_start_values_US_Unem_Cont, US_CarSales_aligned = best_start_values_US_CarSales, 
               US_Unemp_aligned =  best_start_values_US_Unemp, MX_PrivateCons_aligned = best_start_values_MX_PrivateCons, MX_Ind_Act_aligned = best_start_values_MX_Ind_Act, 
               MX_Construction_aligned = best_start_values_MX_Construction, Min_Prod_aligned = best_start_values_Min_Prod, US_Ind_Prod_aligned = best_start_values_US_Ind_Prod,
               IGAE_aligned = best_start_values_IGAE, Cetes_aligned = best_start_values_Cetes, Comm_RealEstate_aligned = best_start_values_Comm_RealEstate, Remittances_aligned = best_start_values_Remittances,
               ExchangeRate_aligned = best_start_values_ExchangeRate, Trade_aligned = best_start_values_Trade)  # Use the best starting values for both US_Unem_Init and US_Unem_Cont
)

summary(final_model_MIDAS1)
summary(final_model_MIDAS2)
summary(final_model_MIDAS3)




# Initialize columns with NA values
data_q$y_hat_MIDAS1 <- NA
data_q$MSPE_MIDAS1 <- NA

# Initialize an empty vector to store the MSPE for each iteration
mspe_values_MIDAS1 <- c()

# Get the total number of observations
n_obs <- nrow(data_q)

# Loop through the data starting from the 71st observation to the last observation
for (i in 71:n_obs) {
  counter <- i - 70
  # Define the training set (first 70 observations for the current iteration)
  train_data <- data_q[1:(i - 1), ]
  
  # Define the test observation (the i-th observation to predict)
  test_data <- data_q[i, , drop = FALSE]  # Ensure that test_data is a data frame (use drop = FALSE)
  
  # Fit the MIDAS regression model on the training set
  final_model_MIDAS1 <- midas_r(
    gdp ~ mls(US_Unem_Init, 0:12, 13, nealmon) + mls(US_Unem_Cont, 0:12, 13, nealmon) + US_Private_Cons_PCFPY + US_GDP_Growth + mls(US_CarSales_aligned, 0:2,3, nealmon) + mls(MX_PrivateCons_aligned, 0:2, 3, nealmon) + mls(MX_Ind_Act_aligned, 0:2, 3, nealmon) + mls(MX_Construction_aligned, 0:2, 3, nealmon) + mls(US_Ind_Prod_aligned, 0:2, 3, nealmon) + mls(IGAE_aligned, 0:2, 3, nealmon),
    start = list(US_Unem_Init = best_start_values_US_Unem_Init, US_Unem_Cont = best_start_values_US_Unem_Cont, US_CarSales_aligned = best_start_values_US_CarSales, MX_PrivateCons_aligned = best_start_values_MX_PrivateCons, MX_Ind_Act_aligned = best_start_values_MX_Ind_Act, 
                 MX_Construction_aligned = best_start_values_MX_Construction, US_Ind_Prod_aligned = best_start_values_US_Ind_Prod, IGAE_aligned = best_start_values_IGAE), data = train_data # Use the best starting values for both US_Unem_Init and US_Unem_Cont
  )
  
  # Predict the next value (the i-th observation)
  prediction <- predict(final_model_MIDAS1, newdata = test_data)
  
  # Ensure that prediction is a scalar (single value)
  prediction <- prediction[i]  # Take the first (and only) value of the prediction
  
  # Get the actual gdp value for the i-th observation
  actual_gdp <- data_q$`Mexico GDP (INEGI, PCFPY)`[i]
  
  # Store the prediction in the data frame as the new variable y_hat_MIDAS_1
  data_q$y_hat_MIDAS1[i] <- prediction
  
  # Calculate the squared prediction error (MSPE)
  mspe <- (actual_gdp - prediction)^2  # MSPE for the i-th observation
  
  # Append the MSPE value to the list
  mspe_values_MIDAS1 <- c(mspe_values_MIDAS1, mspe)
  
  # Store the MSPE in the data frame for the current row
  data_q$MSPE_MIDAS1[i] <- mspe
}

# Calculate the mean of the squared prediction errors (MSPE)
mean_mspe_MIDAS1 <- mean(mspe_values_MIDAS1, na.rm = TRUE)

cat("Mean Squared Prediction Error (MSPE) for MIDAS1:", mean_mspe_MIDAS1, "\n")

mean(data_q$`MSPE_MIDAS1`, na.rm = TRUE)


predictions <- predict(final_model_MIDAS1)






# Initialize columns with NA values
data_q$y_hat_MIDAS2 <- NA
data_q$MSPE_MIDAS2 <- NA

# Initialize an empty vector to store the MSPE for each iteration
mspe_values_MIDAS2 <- c()

# Loop through the data starting from the 71st observation to the last observation
for (i in 71:n_obs) {
  counter <- i - 70
  # Define the training set (first 70 observations for the current iteration)
  train_data_2 <- data_q[1:(i - 1), ]
  
  # Define the test observation (the i-th observation to predict)
  test_data_2 <- data_q[i, , drop = FALSE]  # Ensure that test_data is a data frame (use drop = FALSE)
  
  # Fit the MIDAS regression model on the training set
  final_model_MIDAS2 <- midas_r(
    gdp ~ mls(US_Unem_Init, 0:12, 13, nealmon) + mls(US_Unem_Cont, 0:12, 13, nealmon) + US_Private_Cons_PCFPY + US_GDP_Growth +  MX_retail + mls(US_CarSales_aligned, 0:2,3, nealmon)
    + mls(US_Unemp_aligned, 0:2, 3, nealmon) + mls(MX_PrivateCons_aligned, 0:2, 3, nealmon) + mls(MX_Ind_Act_aligned, 0:2, 3, nealmon) + mls(MX_Construction_aligned, 0:2, 3, nealmon)
    + mls(Min_Prod_aligned, 0:2, 3, nealmon) + mls(US_Ind_Prod_aligned, 0:2, 3, nealmon) + mls(IGAE_aligned, 0:2, 3, nealmon),
    start = list(US_Unem_Init = best_start_values_US_Unem_Init, US_Unem_Cont = best_start_values_US_Unem_Cont, US_CarSales_aligned = best_start_values_US_CarSales, 
                 US_Unemp_aligned =  best_start_values_US_Unemp, MX_PrivateCons_aligned = best_start_values_MX_PrivateCons, MX_Ind_Act_aligned = best_start_values_MX_Ind_Act, 
                 MX_Construction_aligned = best_start_values_MX_Construction, Min_Prod_aligned = best_start_values_Min_Prod, US_Ind_Prod_aligned = best_start_values_US_Ind_Prod,
                 IGAE_aligned = best_start_values_IGAE), data = test_data_2 # Use the best starting values for both US_Unem_Init and US_Unem_Cont
  )
  
  # Predict the next value (the i-th observation)
  prediction_2 <- predict(final_model_MIDAS2, newdata = test_data_2)
  
  # Ensure that prediction is a scalar (single value)
  prediction_2 <- prediction_2[i]  # Take the first (and only) value of the prediction
  
  # Get the actual gdp value for the i-th observation
  actual_gdp_2 <- data_q$`Mexico GDP (INEGI, PCFPY)`[i]
  
  # Store the prediction in the data frame as the new variable y_hat_MIDAS_1
  data_q$y_hat_MIDAS2[i] <- prediction_2
  
  # Calculate the squared prediction error (MSPE)
  mspe2 <- (actual_gdp_2 - prediction_2)^2  # MSPE for the i-th observation
  
  # Append the MSPE value to the list
  mspe_values_MIDAS2 <- c(mspe_values_MIDAS2, mspe2)
  
  # Store the MSPE in the data frame for the current row
  data_q$MSPE_MIDAS2[i] <- mspe2
}

# Calculate the mean of the squared prediction errors (MSPE)
mean_mspe_MIDAS2 <- mean(mspe_values_MIDAS2, na.rm = TRUE)

cat("Mean Squared Prediction Error (MSPE) for MIDAS2:", mean_mspe_MIDAS2, "\n")

mean(data_q$`MSPE_MIDAS2`, na.rm = TRUE)


predictions_2 <- predict(final_model_MIDAS2)



# Calculate the average of MSPE_MIDAS1 and MSPE_MIDAS2 for these observations
average_mspe_midas1 <- mean(data_q$MSPE_MIDAS1, na.rm = TRUE)
average_mspe_midas2 <- mean(data_q$MSPE_MIDAS2, na.rm = TRUE)




data_q <- data_q %>% filter(Date >= as.Date("1996-01-01"))
data_m <- data_m %>% filter(Date >= as.Date("1996-01-01"))
# Initialize columns with NA values
data_q$y_hat_MIDAS3 <- NA
data_q$MSPE_MIDAS3 <- NA

# Initialize an empty vector to store the MSPE for each iteration
mspe_values_MIDAS3 <- c()

# Get the total number of observations
n_obs <- nrow(data_q)

# Loop through the data starting from the 71st observation to the last observation
for (i in 71:n_obs) {
  counter <- i - 70
  # Define the training set (first 70 observations for the current iteration)
  train_data <- data_q[1:(i - 1), ]
  
  # Define the test observation (the i-th observation to predict)
  test_data <- data_q[i, , drop = FALSE]  # Ensure that test_data is a data frame (use drop = FALSE)
  
  # Fit the MIDAS regression model on the training set
  final_model_MIDAS3 <- midas_r(
    gdp ~ mls(US_Unem_Init, 0:12, 13, nealmon) + mls(US_Unem_Cont, 0:12, 13, nealmon) + US_Private_Cons_PCFPY + US_GDP_Growth +  MX_retail + mls(US_CarSales_aligned, 0:2,3, nealmon)
    + mls(US_Unemp_aligned, 0:2, 3, nealmon) + mls(MX_PrivateCons_aligned, 0:2, 3, nealmon) + mls(MX_Ind_Act_aligned, 0:2, 3, nealmon) + mls(MX_Construction_aligned, 0:2, 3, nealmon)
    + mls(Min_Prod_aligned, 0:2, 3, nealmon) + mls(US_Ind_Prod_aligned, 0:2, 3, nealmon) + mls(IGAE_aligned, 0:2, 3, nealmon) +mls(Cetes_aligned, 0:2, 3, nealmon) 
    + mls(Comm_RealEstate_aligned, 0:2, 3, nealmon) + mls(Remittances_aligned, 0:2, 3, nealmon) + mls(ExchangeRate_aligned, 0:2, 3, nealmon) + mls(Trade_aligned, 0:2, 3, nealmon),
    start = list(US_Unem_Init = best_start_values_US_Unem_Init, US_Unem_Cont = best_start_values_US_Unem_Cont, US_CarSales_aligned = best_start_values_US_CarSales, 
                 US_Unemp_aligned =  best_start_values_US_Unemp, MX_PrivateCons_aligned = best_start_values_MX_PrivateCons, MX_Ind_Act_aligned = best_start_values_MX_Ind_Act, 
                 MX_Construction_aligned = best_start_values_MX_Construction, Min_Prod_aligned = best_start_values_Min_Prod, US_Ind_Prod_aligned = best_start_values_US_Ind_Prod,
                 IGAE_aligned = best_start_values_IGAE, Cetes_aligned = best_start_values_Cetes, Comm_RealEstate_aligned = best_start_values_Comm_RealEstate, Remittances_aligned = best_start_values_Remittances,
                 ExchangeRate_aligned = best_start_values_ExchangeRate, Trade_aligned = best_start_values_Trade) # Use the best starting values for both US_Unem_Init and US_Unem_Cont
  )
  
  # Predict the next value (the i-th observation)
  prediction_3 <- predict(final_model_MIDAS3, newdata = test_data)
  
  # Ensure that prediction is a scalar (single value)
  prediction_3 <- prediction_3[i]  # Take the first (and only) value of the prediction
  
  # Get the actual gdp value for the i-th observation
  actual_gdp_3 <- data_q$`Mexico GDP (INEGI, PCFPY)`[i]
  
  # Store the prediction in the data frame as the new variable y_hat_MIDAS_1
  data_q$y_hat_MIDAS3[i] <- prediction_3
  
  # Calculate the squared prediction error (MSPE)
  mspe_3 <- (actual_gdp_3 - prediction_3)^2  # MSPE for the i-th observation
  
  # Append the MSPE value to the list
  mspe_values_MIDAS3 <- c(mspe_values_MIDAS3, mspe_3)
  
  # Store the MSPE in the data frame for the current row
  data_q$MSPE_MIDAS3[i] <- mspe_3
}

# Calculate the mean of the squared prediction errors (MSPE)
mean_mspe_MIDAS3 <- mean(mspe_values_MIDAS3, na.rm = TRUE)

cat("Mean Squared Prediction Error (MSPE) for MIDAS3:", mean_mspe_MIDAS3, "\n")

mean(data_q$`MSPE_MIDAS3`, na.rm = TRUE)


predictions <- predict(final_model_MIDAS3)


# Filter the rows where the observation number is greater than 70
filtered_data <- data_q[71:nrow(data_q), ]
average_mspe_midas3 <- mean(filtered_data$MSPE_MIDAS3, na.rm = TRUE)



# Filter data for dates after 2005
data_q_filtered <- data_q %>%
  filter(Date > as.Date("2011-01-01"))

# Prepare the plot data
plot_data <- data.frame(
  Date = data_q_filtered$Date,  # Dates after 2005
  Actual_GDP = data_q_filtered$`Mexico GDP (INEGI, PCFPY)`,  # Actual GDP values
  MIDAS1_Predicted_GDP = data_q_filtered$y_hat_MIDAS1,  # MIDAS1 predictions
  MIDAS2_Predicted_GDP = data_q_filtered$y_hat_MIDAS2,  # MIDAS2 predictions
  MIDAS3_Predicted_GDP = data_q_filtered$y_hat_MIDAS3  # MIDAS3 predictions
)

# Create the plot
ggplot(plot_data, aes(x = Date)) +
  geom_line(aes(y = Actual_GDP), color = "black", size = 1) +  # Actual GDP in black
  geom_line(aes(y = MIDAS1_Predicted_GDP), color = "red", size = 1, linetype = "dashed") +  # MIDAS1 predictions in red (dashed)
  geom_line(aes(y = MIDAS2_Predicted_GDP), color = "blue", size = 1, linetype = "dotted") +  # MIDAS2 predictions in blue (dotted)
  geom_line(aes(y = MIDAS3_Predicted_GDP), color = "green", size = 1, linetype = "twodash") +  # MIDAS3 predictions in green (twodash)
  labs(title = "Actual vs Out-of-Sample Predictions Midas_(1, 2, 3)",
       x = "Date", 
       y = "GDP",
       caption = "Black: Actual GDP, Red Dashed: MIDAS1, Blue Dotted: MIDAS2, Green Twodash: MIDAS3") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))


cat("Mean Squared Prediction Error (MSPE) for MIDAS1:", average_mspe_midas1, "\n")
cat("Mean Squared Prediction Error (MSPE) for MIDAS2:", average_mspe_midas2, "\n")
cat("Mean Squared Prediction Error (MSPE) for MIDAS3:", average_mspe_midas3, "\n")






















