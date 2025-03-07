library(plumber)

# Create and configure the API using the updated plumber 1.0.0+ approach
# Instead of using plumber$new(), we'll use pr() and a programmatic approach
report_dir <- here::here('shrp2c16', "projects", "project", "reports")

# Get the API from the current file
api <- pr(file = "plumber_app.R")

# Configure static file serving
api <- pr_static(api, "/", file.path(dir, "gui", "views"))
api <- pr_static(api, "/reports", report_dir)

# Open browser
later::later(function() {
  utils::browseURL("http://localhost:8765")
}, 2)

# Start the server
pr_run(api, host = "127.0.0.1", port = 8765, docs = FALSE)