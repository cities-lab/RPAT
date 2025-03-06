#!/usr/bin/env Rscript

# Load required packages
if (!require("logger")) install.packages("logger")
if (!require("here")) install.packages("here")

library(plumber)
library(logger)
library(here)

# Configure logger
my_formatter <- logger::formatter_sprintf
logger::log_formatter(my_formatter)
log_appender(appender_file(here::here("shrp2c16", "rpat.log")))
log_threshold(TRACE)
log_info("RPAT launcher starting")

views_dir <- here::here("shrp2c16", "gui", "views")
report_dir <- here::here("shrp2c16", "projects", "project", "reports")

  # Get the API from the current file
pr <- pr(file = "plumber_app.R")

# Configure static file serving
#api <- pr_static(api, "/", views_dir)
#api <- pr_static(api, "/reports", report_dir)

    # Mount the root views directory (serves index.html and other root files)
pr <- pr |> 
    pr_static("/", views_dir)

# Mount CSS directory
css_dir <- here::here("shrp2c16", "gui", "views", "CSS")
if (dir.exists(css_dir)) {
    log_info("CSS directory exists at: %s", css_dir)
    pr <- pr |> 
    pr_static("/CSS", css_dir)
} else {
    log_warn("CSS directory not found at: %s", css_dir)
}

# Mount JavaScript directory
js_dir <- here::here("shrp2c16", "gui", "views", "JScripts")
if (dir.exists(js_dir)) {
    log_info("JS directory exists at: %s", js_dir)
    pr <- pr |> 
    pr_static("/JScripts", js_dir)
} else {
    log_warn("JS directory not found at: %s", js_dir)
}

# Mount image directory
img_dir <- here::here("shrp2c16", "gui", "views", "img")
if (dir.exists(img_dir)) {
    log_info("Image directory exists at: %s", img_dir)
    pr <- pr |> 
    pr_static("/img", img_dir)
} else {
    log_warn("Image directory not found at: %s", img_dir)
}

# Mount docs directory
docs_dir <- here::here("shrp2c16", "gui", "views", "docs")
if (dir.exists(docs_dir)) {
    log_info("Docs directory exists at: %s", docs_dir)
    pr <- pr |> 
    pr_static("/docs", docs_dir)
} else {
    log_warn("Docs directory not found at: %s", docs_dir)
}

# Mount reports directory
reports_dir <- here::here("shrp2c16", "projects", "project", "reports")
if (dir.exists(reports_dir)) {
    log_info("Reports directory exists at: %s", reports_dir)
    pr <- pr |> 
    pr_static("/reports", reports_dir)
} else {
    log_info("Reports directory not found, creating at: %s", reports_dir)
    dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)
    pr <- pr |> 
    pr_static("/reports", reports_dir)
}

# Start the server
pr_run(pr, host = "127.0.0.1", port = 8765, docs = FALSE)

# Open browser
browseURL("http://127.0.0.1:8765/index.html")


# # Source the plumber app definition
# log_info("Sourcing plumber_app.R")
# source("plumber_app.R")

# # Call the function to create and run the API server
# log_info("Calling create_launcher_script()")
# create_launcher_script()

# utils::browseURL("http://127.0.0.1:8765/")