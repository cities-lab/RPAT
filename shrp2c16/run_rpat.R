#!/usr/bin/env Rscript

# Load required packages
if (!require("logger")) install.packages("logger")
if (!require("here")) install.packages("here")

library(logger)
library(here)

# Configure logger
my_formatter <- logger::formatter_sprintf
logger::log_formatter(my_formatter)
log_appender(appender_file(here::here("shrp2c16", "rpat.log")))
log_threshold(TRACE)
log_info("RPAT launcher starting")

# Source the plumber app definition
log_info("Sourcing plumber_app.R")
source("gui/plumber_app.R")

# Call the function to create and run the API server
log_info("Calling create_launcher_script()")
create_launcher_script()
