#!/usr/bin/env Rscript

# Load required packages
if (!require("logger")) install.packages("logger")
if (!require("here")) install.packages("here")

library(plumber)
library(logger)
library(here)

source("plumber_app.R")

# Call the function to create and run the API server
log_info("Calling create_launcher_script()")
create_launcher_script()

utils::browseURL("http://127.0.0.1:8765/")