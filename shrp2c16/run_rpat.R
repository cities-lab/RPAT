library(plumber)

# Create and configure the API using the updated plumber 1.0.0+ approach
# Instead of using plumber$new(), we'll use pr() and a programmatic approach
dir <- getwd()
report_dir <- file.path(getwd(), "projects", "project", "reports")

# Get the API from the current file
api <- pr(file = "plumber_app.R")

# Configure static file serving
api <- pr_static(api, "/", file.path(dir, "gui", "views"))
api <- pr_static(api, "/reports", report_dir)

# Start the server
pr_run(api, host = "0.0.0.0", port = 8765, docs = FALSE)

# Open browser
#browseURL("http://127.0.0.1:8765/index.html")