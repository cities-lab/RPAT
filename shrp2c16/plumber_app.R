#!/usr/bin/env Rscript

# Load required packages
if (!require("plumber")) install.packages("plumber")
if (!require("jsonlite")) install.packages("jsonlite")
if (!require("tools")) install.packages("tools")
if (!require("httr")) install.packages("httr")
if (!require("ps")) install.packages("ps")
if (!require("here")) install.packages("here")
if (!require("logger")) install.packages("logger")

library(plumber)
library(jsonlite)
library(tools)
library(httr)
library(ps)
library(here)
library(logger)
library(fs)

# Fix logger initialization
# Some basic configurations
my_formatter <- logger::formatter_sprintf
logger::log_formatter(my_formatter)
log_appender(appender_file(here::here("shrp2c16", "rpat_api.log")))
log_threshold(TRACE)
log_info("RPAT API starting")

# Global variables
global_popen <- NULL
root_dir <- here::here()
views_dir <- here::here("shrp2c16", "gui", "views")
report_dir <- here::here("shrp2c16", "projects", "project", "reports")

# Determine which Rscript executable to use based on OS
rscript_cmd <- if (.Platform$OS.type == "windows") here::here("shrp2c16", "Rscript.bat") else "Rscript"
log_info("Using R script command: %s", rscript_cmd)

log_info("Root directory: %s", root_dir)
log_info("Views directory: %s", views_dir)
log_info("Report directory: %s", report_dir)

# Helper function to kill any existing RPAT processes
kill_existing_processes <- function() {
  # Remove the stdout.txt file
  stdout_path <- here::here("shrp2c16", "stdout.txt")
  
  # Initialize stdout.txt
  writeLines("", stdout_path)
  log_info("Initialized stdout.txt")
  
  # Kill any existing RPAT processes
  ps_list <- ps::ps()
  for (proc in 1:nrow(ps_list)) {
    if (grepl("RPAT", ps_list$name[proc]) && ps_list$pid[proc] != Sys.getpid()) {
      message(paste("Stopped R Process", ps_list$pid[proc]))
      log_info("Stopped R Process %s", ps_list$pid[proc])
      ps::ps_kill(ps_list$pid[proc])
    }
  }
}

# Basic API definition
#* @apiTitle RPAT API
#* @apiDescription REST API for RPAT application

#* @filter logger
function(req, res) {
  log_info("Request: %s %s", req$REQUEST_METHOD, req$PATH_INFO)
  plumber::forward()
}

#* @filter cors
function(req, res) {
  # Log the request URL for debugging
  log_info("Request URL: %s %s", req$REQUEST_METHOD, req$PATH_INFO)
  # Log all request headers for debugging
  for (name in names(req$HTTP_HEADERS)) {
    log_debug("Header: %s = %s", name, req$HTTP_HEADERS[[name]])
  }
  
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  
  # Only set Content-Type to application/json for API endpoints, not for static assets
  if (!grepl("^/(CSS|JScripts|img|image)/", req$PATH_INFO)) {
    res$setHeader("Content-Type", "application/json")
  }
  
  plumber::forward()
}

#* @get /api/status
#* @serializer json
function() {
  log_info("GET /api/status request received")
  return(list(status = "ok", time = format(Sys.time())))
}

#* @get /scenarioes
#* @serializer json
function() {
  log_info("GET /scenarioes request received")
  path <- here::here("shrp2c16", "projects", "project")
  directories <- c()
  
  if (dir.exists(path)) {
    all_dirs <- list.files(path)
    directories <- all_dirs[!all_dirs %in% c("parameters", "reports")]
  } else {
    dir.create(path, recursive = TRUE)
    directories <- list.files(path)
  }
  
  log_info("Found %d scenarios", length(directories))
  return(list(scenarios = directories))
}

#* @get /runstatus
#* @serializer json
function() {
  log_info("GET /runstatus request received")
  stdout_path <- here::here("shrp2c16", "stdout.txt")
  if (file.exists(stdout_path)) {
    content <- readLines(stdout_path, n = 1, warn = FALSE)
    log_info("Read content from stdout.txt: %s", content)
    return(list(output = content))
  } else {
    log_warn("stdout.txt does not exist")
    return(list(output = ""))
  }
}

#* @get /scenarioes_to_copy
#* @serializer json
function() {
  log_info("GET /scenarioes_to_copy request received")
  root_scenarios <- c("template")
  scenarios <- c()
  
  path <- here::here("shrp2c16", "projects", "project")
  if (dir.exists(path)) {
    all_dirs <- list.files(path)
    scenarios <- all_dirs[!all_dirs %in% c("parameters", "reports")]
  }
  
  log_info("Found %d scenarios", length(scenarios))
  return(list(root_scenarios = root_scenarios, scenarios = scenarios))
}

#* @get /state_files/:name
#* @serializer json
function(req, name) {
  log_info("GET /state_files/%s request received", name)
  path <- here::here("shrp2c16", "projects", "project", name, "parameters")
  
  # Create the parameters directory if it doesn't exist
  if (!dir.exists(path)) {
    log_info("Creating missing parameters directory: %s", path)
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  
  if (dir.exists(path)) {
    files <- list.files(path)
    log_info("Found %d files", length(files))
    return(list(files = files))
  } else {
    log_error("Failed to create parameters directory: %s", path)
    return(list(files = c(), error = "Failed to create parameters directory"))
  }
}

#* @get /new_scenario
#* @serializer json
function(name, fromScenario, isFirst) {
  log_info("GET /new_scenario request received with name: %s, fromScenario: %s, isFirst: %s", 
           name, fromScenario, isFirst)
  
  newdir <- here::here("shrp2c16", "projects", "project", name)
  log_info("Target directory: %s", newdir)
  
  # Check if directory already exists
  if (!dir.exists(newdir)) {
    log_info("Directory does not exist, creating new scenario")
    
    # Check source directory based on fromScenario parameter
    if (grepl("^template", fromScenario)) {
      demo_dir <- here::here("shrp2c16", "projects", "Demo Project", "base")
      log_info("Source directory (template): %s", demo_dir)
      
      if (dir.exists(demo_dir)) {
        log_info("Template directory exists, copying")
        success <- dir.create(newdir, recursive = TRUE)
        
        if (success) {
          # Copying files from template to new directory
          file_list <- list.files(demo_dir, recursive = TRUE)
          for (file in file_list) {
            source_file <- file.path(demo_dir, file)
            dest_file <- file.path(newdir, file)
            
            # Create parent directories if needed
            if (!dir.exists(dirname(dest_file))) {
              dir.create(dirname(dest_file), recursive = TRUE)
            }
            
            # Copy the file
            if (!dir.exists(source_file)) {
              file.copy(source_file, dest_file)
            }
          }
          log_info("Copied template files to new scenario directory")
        } else {
          log_error("Failed to create new scenario directory")
          return(list(success = FALSE, error = "Failed to create directory"))
        }
      } else {
        log_error("Template directory does not exist: %s", demo_dir)
        return(list(success = FALSE, error = "Template directory not found"))
      }
    } else {
      # Copying from existing scenario
      source_dir <- here::here("shrp2c16", "projects", "project", fromScenario)
      log_info("Source directory (existing scenario): %s", source_dir)
      
      if (dir.exists(source_dir)) {
        log_info("Source scenario exists, copying")
        success <- dir.create(newdir, recursive = TRUE)
        
        if (success) {
          # Copying files from source to new directory
          file_list <- list.files(source_dir, recursive = TRUE)
          for (file in file_list) {
            source_file <- file.path(source_dir, file)
            dest_file <- file.path(newdir, file)
            
            # Create parent directories if needed
            if (!dir.exists(dirname(dest_file))) {
              dir.create(dirname(dest_file), recursive = TRUE)
            }
            
            # Copy the file
            if (!dir.exists(source_file)) {
              file.copy(source_file, dest_file)
            }
          }
          log_info("Copied source scenario files to new scenario directory")
        } else {
          log_error("Failed to create new scenario directory")
          return(list(success = FALSE, error = "Failed to create directory"))
        }
      } else {
        log_error("Source scenario directory does not exist: %s", source_dir)
        return(list(success = FALSE, error = "Source scenario directory not found"))
      }
    }
    
    # Create timestamp file
    timestamp_file <- file.path(newdir, "time.txt")
    writeLines(format(Sys.time(), "%a %b %d %H:%M:%S %Y"), timestamp_file)
    log_info("Created timestamp file: %s", timestamp_file)
    
    log_info("Successfully created new scenario: %s", name)
    return(list(success = TRUE))
  } else {
    log_warn("Scenario directory already exists: %s", newdir)
    return(list(success = FALSE, error = "Scenario already exists"))
  }
}

#* @get /delete_scenario
#* @serializer json
function(req, name) {
  log_info("GET /delete_scenario request received with name: %s", name)
  
  scenario_dir <- here::here("shrp2c16", "projects", "project", name)
  if (dir.exists(scenario_dir)) {
    tryCatch({
      unlink(scenario_dir, recursive = TRUE)
      log_info("Successfully deleted scenario: %s", name)
      return(list(success = TRUE))
    }, error = function(e) {
      log_error("Failed to delete scenario: %s. Error: %s", name, conditionMessage(e))
      return(list(success = FALSE, error = conditionMessage(e)))
    })
  } else {
    log_warn("Scenario directory does not exist: %s", scenario_dir)
    return(list(success = FALSE, error = "Scenario directory not found"))
  }
}

#* @get /scenario
#* @serializer json
function(req, name) {
  log_info("GET /scenario request received for name: %s", name)
  
  path <- here::here("shrp2c16", "projects", "project", name, "inputs")
  if (dir.exists(path)) {
    files <- list.files(path)
    log_info("Found %d input files for scenario: %s", length(files), name)
    
    # Initialize file_edits array with FALSE for each file
    file_edits <- rep(FALSE, length(files))
    
    return(list(files = files, file_edits = file_edits, state = "CA")) # Default state value
  } else {
    log_warn("Input directory does not exist for scenario: %s", name)
    return(list(files = c(), file_edits = c(), state = ""))
  }
}

#* @get /loadcsvfile
#* @serializer json
function(req, name, fileName) {
  log_info("GET /loadcsvfile request received for scenario: %s, file: %s", name, fileName)
  
  file_path <- here::here("shrp2c16", "projects", "project", name, "inputs", fileName)
  if (file.exists(file_path)) {
    tryCatch({
      data <- read.csv(file_path, header = TRUE, stringsAsFactors = FALSE)
      
      # Convert data to the format expected by the client
      result <- list()
      # Add header row as an array, not as a named list
      result[[1]] <- colnames(data)
      
      # Add data rows as arrays, not as named lists
      for(i in 1:nrow(data)) {
        result[[i+1]] <- as.character(unlist(data[i,]))
      }
      
      log_info("Successfully loaded CSV file: %s with %d rows", fileName, length(result))
      return(list(data = result))
    }, error = function(e) {
      log_error("Error loading CSV file: %s. Error: %s", fileName, conditionMessage(e))
      return(list(data = list(), error = conditionMessage(e)))
    })
  } else {
    log_warn("CSV file does not exist: %s", file_path)
    return(list(data = list(), error = "File not found"))
  }
}

#* @get /loadTextFile
#* @serializer json
function(req, name, fileName) {
  log_info("GET /loadTextFile request received for scenario: %s, file: %s", name, fileName)
  
  file_path <- here::here("shrp2c16", "projects", "project", name, "inputs", fileName)
  if (file.exists(file_path)) {
    tryCatch({
      lines <- readLines(file_path)
      
      # Convert to list of single-element lists for client-side rendering
      result <- lapply(lines, function(line) list(line))
      
      log_info("Successfully loaded text file: %s with %d lines", fileName, length(result))
      return(list(data = result))
    }, error = function(e) {
      log_error("Error loading text file: %s. Error: %s", fileName, conditionMessage(e))
      return(list(data = list(), error = conditionMessage(e)))
    })
  } else {
    log_warn("Text file does not exist: %s", file_path)
    return(list(data = list(), error = "File not found"))
  }
}

#* @get /loadstatecsvfile
#* @serializer json
function(req, name, fileName, directory = "root") {
  log_info("GET /loadstatecsvfile request received for scenario: %s, file: %s, directory: %s", 
           name, fileName, directory)
  
  # Determine file path based on directory parameter
  file_path <- here::here("shrp2c16", "projects", "project", name, "parameters", fileName)
  
  # Ensure parent directory exists
  parent_dir <- dirname(file_path)
  if (!dir.exists(parent_dir)) {
    log_info("Creating missing parent directory: %s", parent_dir)
    dir.create(parent_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  tryCatch({
    if (file.exists(file_path)) {
      # Read the CSV file
      csv_data <- read.csv(file_path, header = FALSE, stringsAsFactors = FALSE)
      row_count <- nrow(csv_data)
      log_info("Successfully loaded state CSV file: %s with %d rows", fileName, row_count)
      
      # Convert to list format - maintain row orientation
      # First convert data.frame to list of rows
      rows_list <- lapply(1:nrow(csv_data), function(i) as.list(csv_data[i,]))
      result <- list(data = rows_list)
      
      # Let Plumber handle the headers
      return(result)
    } else {
      log_warn("State CSV file not found: %s", file_path)
      
      # If file doesn't exist, try to create a default empty file
      # This could be customized based on file type
      empty_data <- data.frame(matrix(ncol = 1, nrow = 0))
      write.csv(empty_data, file = file_path, row.names = FALSE, col.names = FALSE)
      
      log_info("Created empty state CSV file: %s", file_path)
      
      # Let Plumber handle the headers
      return(list(data = list(), warning = "File not found, created empty file"))
    }
  }, error = function(e) {
    # Generate a traceback string
    tb <- paste(capture.output(traceback()), collapse = "\n")
    log_error("Error loading state CSV file: %s. Error: %s\nTraceback: %s", fileName, conditionMessage(e), tb)
    
    # Set response headers even on error
    req$res$setHeader("Access-Control-Allow-Origin", "*")
    req$res$setHeader("Content-Type", "application/json")
    req$res$setHeader("X-Plumber-Error", "true")
    
    return(list(error = conditionMessage(e)))
  })
}

#* @get /loadstatetextfile
#* @serializer json
function(req, name, fileName, directory = "root") {
  log_info("GET /loadstatetextfile request received for scenario: %s, file: %s, directory: %s", 
           name, fileName, directory)
  
  base_path <- if (directory == "root") {
    here::here("shrp2c16", "projects", "project", name, "parameters")
  } else {
    here::here("shrp2c16", "projects", "project", name, "parameters", directory)
  }
  
  file_path <- file.path(base_path, fileName)
  # Ensure parent directory exists
  parent_dir <- dirname(file_path)
  if (!dir.exists(parent_dir)) {
    log_info("Creating missing parent directory: %s", parent_dir)
    dir.create(parent_dir, recursive = TRUE, showWarnings = FALSE)
  }

  tryCatch({
    if (file.exists(file_path)) {
      lines <- readLines(file_path)
      
      # Convert to list of single-element lists for client-side rendering
      result <- lapply(lines, function(line) list(line))
      
      log_info("Successfully loaded state text file: %s with %d lines", fileName, length(result))
      return(list(data = result))
    } else {
      log_warn("State text file does not exist: %s", file_path)
      
      # Create an empty file with default content
      writeLines("", file_path)
      log_info("Created empty state text file: %s", file_path)
      
      return(list(data = list(), warning = "File not found, created empty file"))
    }
  }, error = function(e) {
    # Generate a traceback string
    tb <- paste(capture.output(traceback()), collapse = "\n")
    log_error("Error loading state text file: %s. Error: %s\nTraceback: %s", fileName, conditionMessage(e), tb)
    
    return(list(error = conditionMessage(e)))
  })
}

#* @get /load_documentation
#* @serializer json
function(filename) {
  log_info("GET /load_documentation request received for file: %s", filename)
  
  docs_path <- here::here("shrp2c16", "gui", "views", "docs", filename)
  if (file.exists(docs_path)) {
    tryCatch({
      content <- paste(readLines(docs_path, warn = FALSE), collapse = "\n")
      log_info("Successfully loaded documentation file: %s with %d characters", filename, nchar(content))
      return(list(data = content))
    }, error = function(e) {
      log_error("Error loading documentation file: %s. Error: %s", filename, conditionMessage(e))
      return(list(data = "", error = conditionMessage(e)))
    })
  } else {
    log_warn("Documentation file does not exist: %s", docs_path)
    return(list(data = "", error = "File not found"))
  }
}

#* @post /savecsvfile
#* @serializer json
function(req, data, name, fileName) {
  log_info("POST /savecsvfile request received for scenario: %s, file: %s", name, fileName)
  
  tryCatch({
    # Parse the JSON data directly
    parsed_data <- jsonlite::fromJSON(data)
    
    file_path <- here::here("shrp2c16", "projects", "project", name, "inputs", fileName)
    
    # Create directory if it doesn't exist
    dir.create(dirname(file_path), recursive = TRUE, showWarnings = FALSE)
    
    # Write data to CSV
    con <- file(file_path, "w")
    write.table(parsed_data, con, sep = ",", quote = FALSE, 
                row.names = FALSE, col.names = FALSE)
    close(con)
    
    log_info("Successfully saved CSV file: %s", file_path)
    
    # Set response headers to ensure AJAX completes properly
    req$res$setHeader("Access-Control-Allow-Origin", "*")
    req$res$setHeader("Content-Type", "application/json")
    req$res$setHeader("X-Plumber-Success", "true")  # Custom header to signal success
    
    # Return exact format from Python implementation
    return(list(success = TRUE))
  }, error = function(e) {
    log_error("Error saving CSV file: %s. Error: %s", fileName, conditionMessage(e))
    
    # Set response headers even on error
    req$res$setHeader("Access-Control-Allow-Origin", "*")
    req$res$setHeader("Content-Type", "application/json")
    req$res$setHeader("X-Plumber-Error", "true")  # Custom header to signal error
    
    return(list(success = FALSE))
  })
}

#* @get /loadoutputcsvfile
#* @param name
#* @param fileName
loadoutputcsvfile <- function(req, name="", fileName=""){
  file_path <- here::here("shrp2c16", "projects", "project", name, "outputs", fileName)
  out <- read.csv(file_path, header = FALSE, stringsAsFactors = FALSE)
  list(data = unname(lapply(1:nrow(out), function(i) as.list(out[i,])))) # Convert to list of lists and remove names
}

#* @post /savestatecsvfile
#* @serializer json
function(req, res, data, name, fileName, directory = "root") {
  log_info("POST /savestatecsvfile request received for scenario: %s, file: %s, directory: %s", 
           name, fileName, directory)
  
  # Use identical structure to the Python implementation
  tryCatch({
    # Parse the JSON data just like the Python implementation
    parsed_data <- jsonlite::fromJSON(data, simplifyVector = FALSE)
    
    # Determine the file path - exactly matching Python path
    file_path <- file.path(getwd(), "projects", "project", name, "parameters", fileName)
    
    # Create directory if it doesn't exist
    parent_dir <- dirname(file_path)
    if (!dir.exists(parent_dir)) {
      dir.create(parent_dir, recursive = TRUE, showWarnings = FALSE)
    }
    
    # Use a similar approach to the Python CSV writer
    file_conn <- NULL
    tryCatch({
      # Create a simple CSV writer like Python - using csvfile mode
      csv_data <- lapply(parsed_data, function(row) {
        # Extract values, handling arrays by taking first element
        unlist(lapply(row, function(cell) {
          if (is.list(cell) && length(cell) > 0) {
            as.character(cell[[1]])
          } else {
            as.character(cell)
          }
        }))
      })
      
      # Write using write.table which is closer to Python's CSV writer
      write.table(
        do.call(rbind, csv_data),
        file = file_path,
        sep = ",",
        row.names = FALSE,
        col.names = FALSE,
        quote = FALSE
      )
      
      log_info("Successfully saved state CSV file: %s", file_path)
    }, finally = {
      # No explicit file closing needed with write.table
    })
    
    # Set headers exactly as CherryPy would
    res$setHeader("Access-Control-Allow-Origin", "*")
    res$setHeader("Content-Type", "application/json")
    
    # Add a custom header to trigger unblockUI in the JavaScript
    res$setHeader("X-UnblockUI", "true")
    
    # Return the exact same structure as Python's return
    return(list(success = TRUE, unblock = TRUE))
    
  }, error = function(e) {
    log_error("Error saving CSV: %s", conditionMessage(e))
    
    # Set headers for error case
    res$setHeader("Access-Control-Allow-Origin", "*")
    res$setHeader("Content-Type", "application/json")
    res$status <- 500
    
    # Return error response
    return(list(success = FALSE))
  })
}

#* @get /get_default_state
#* @serializer json
function() {
  log_info("GET /get_default_state request received")
  
  # Try to read the state.txt file if it exists
  state_file <- here::here("shrp2c16", "state.txt")
  state <- NULL
  
  if (file.exists(state_file)) {
    state <- readLines(state_file, warn = FALSE)
    log_info("Read state from file: %s", paste(state, collapse = ", "))
  } else {
    log_warn("State file does not exist: %s", state_file)
  }
  
  return(list(state = state))
}

#* @get /set_default_state
#* @serializer json
function(state) {
  log_info("GET /set_default_state request received with state: %s", state)
  
  state_file <- here::here("shrp2c16", "state.txt")
  tryCatch({
    writeLines(state, state_file)
    log_info("Successfully wrote state to file: %s", state_file)
    return(list(success = TRUE))
  }, error = function(e) {
    log_error("Error writing state to file: %s. Error: %s", state_file, conditionMessage(e))
    return(list(success = FALSE, error = conditionMessage(e)))
  })
}

#* @get /resetrunstatus
#* @serializer json
function() {
  log_info("GET /resetrunstatus request received")
  
  stdout_path <- here::here("shrp2c16", "stdout.txt")
  tryCatch({
    writeLines("pending", stdout_path)
    log_info("Reset run status to 'pending'")
    return(list(Status = "Success"))
  }, error = function(e) {
    log_error("Error resetting run status: %s", conditionMessage(e))
    return(list(Status = "Error", Message = conditionMessage(e)))
  })
}

#* @get /output_files
#* @serializer json
function(req, name) {
  log_info("GET /output_files request received for scenario: %s", name)
  
  output_dir <- here::here("shrp2c16", "projects", "project", name, "outputs")
  
  # Create the output directory if it doesn't exist
  if (!dir.exists(output_dir)) {
    log_info("Creating missing output directory: %s", output_dir)
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  if (dir.exists(output_dir)) {
    files <- list.files(output_dir)
    log_info("Found %d output files", length(files))
    return(list(files = files))
  } else {
    log_error("Failed to create output directory: %s", output_dir)
    return(list(files = c(), error = "Failed to create output directory"))
  }
}

#* @get /state_files
#* @serializer json
function(name = NULL) {
  if (is.null(name)) {
    log_warn("GET /state_files request received without a name parameter")
    return(list(files = c(), error = "Missing required parameter: name"))
  }
  
  log_info("GET /state_files request received for name: %s", name)
  path <- here::here("shrp2c16", "projects", "project", name, "parameters")
  
  # Create the parameters directory if it doesn't exist
  if (!dir.exists(path)) {
    log_info("Creating missing parameters directory: %s", path)
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  
  if (dir.exists(path)) {
    files <- list.files(path)
    log_info("Found %d files", length(files))
    return(list(files = files))
  } else {
    log_error("Failed to create parameters directory: %s", path)
    return(list(files = c(), error = "Failed to create parameters directory"))
  }
}

#* @get /startrun
#* @serializer json
function(req, name) {
  log_info("GET /startrun request received for scenario: %s", name)
  
  # Reset stdout.txt to 'pending'
  stdout_path <- here::here("shrp2c16", "stdout.txt")
  writeLines("pending", stdout_path)
  
  # Get the path to the scenario directory
  scenario_dir <- here::here("shrp2c16", "projects", "project", name)
  script_path <- here::here("shrp2c16", "scripts", "SmartGAP.r")
  
  # Check if directories and files exist
  if (!dir.exists(scenario_dir)) {
    log_error("Scenario directory does not exist: %s", scenario_dir)
    return(list(success = FALSE, error = paste("Scenario directory does not exist:", scenario_dir)))
  }
  
  if (!file.exists(script_path)) {
    log_error("Script file does not exist: %s", script_path)
    return(list(success = FALSE, error = paste("Script file does not exist:", script_path)))
  }
  
  log_info("Starting model run for scenario: %s", name)
  log_info("Working directory: %s", scenario_dir)
  log_info("Script path: %s", script_path)

  #log_path <- here::here("shrp2c16", "rpat_run.log")

  # Run the R script as a separate process and capture output to sim.log
  
  # Create the system command to run the R script
  cmd_args <- c(shQuote(script_path), "-s", shQuote(name))
  
  # Execute the command and redirect output to sim.log
  # On Mac/Linux, we can use system() with wait=FALSE to run asynchronously
  result <- system2(rscript_cmd, args = cmd_args, stdout = FALSE, stderr = FALSE, wait = TRUE)
  #log_info(result)

  # Also write to stdout.txt for status monitoring
  #stdout_path <- here::here("shrp2c16", "stdout.txt")
  #writeLines("done", stdout_path)
  
  return(list(success = TRUE, message = "Model run started"))

}

#* @get /stoprun
#* @serializer json
function() {
  log_info("GET /stoprun request received")
  
  tryCatch({
    # Stop any running R processes that might be related to RPAT
    ps_list <- ps::ps()
    for (proc in 1:nrow(ps_list)) {
      # On Mac, we need to check different fields than on Windows
      proc_cmd <- ""
      if ("cmd" %in% names(ps_list)) {
        proc_cmd <- ps_list$cmd[proc]
      } else if ("exe" %in% names(ps_list)) {
        proc_cmd <- ps_list$exe[proc]
      } else if ("name" %in% names(ps_list)) {
        proc_cmd <- ps_list$name[proc]
      }
      
      if ((grepl("Rscript", proc_cmd) || grepl("SmartGAP", proc_cmd)) && 
          ps_list$pid[proc] != Sys.getpid()) {
        log_info("Stopping R Process %s with command: %s", ps_list$pid[proc], proc_cmd)
        ps::ps_kill(ps_list$pid[proc])
      }
    }
    
    # Reset stdout.txt
    stdout_path <- here::here("shrp2c16", "stdout.txt")
    writeLines("", stdout_path)
    
    return(list(success = TRUE, message = "Model run stopped"))
  }, error = function(e) {
    # Generate a traceback string
    tb <- paste(capture.output(traceback()), collapse = "\n")
    log_error("Error stopping model run: %s\nTraceback: %s", conditionMessage(e), tb)
    
    # Set response headers even on error
    req$res$setHeader("Access-Control-Allow-Origin", "*")
    req$res$setHeader("Content-Type", "application/json")
    req$res$setHeader("X-Plumber-Error", "true")
    
    return(list(success = FALSE, error = conditionMessage(e)))
  })
}

#* @get /runReport
#* @serializer json
function(req) {
  log_info("GET /runReport request received")
  
  # Extract parameters from the query string
  params <- req$argsQuery
  
  # Extract scenario, metric, and measure values
  scenarios <- unlist(params[grep("^scenarios\\[", names(params))])
  metrics <- unlist(params[grep("^metrics\\[", names(params))])
  measures <- unlist(params[grep("^measures\\[", names(params))])
  
  # Handle case when only one scenario/metric/measure is selected
  if (length(scenarios) == 0 && !is.null(params$scenarios)) {
    scenarios <- params$scenarios
    if (!is.vector(scenarios)) scenarios <- c(scenarios)
  }
  if (length(metrics) == 0 && !is.null(params$metrics)) {
    metrics <- params$metrics
    if (!is.vector(metrics)) metrics <- c(metrics)
  }
  if (length(measures) == 0 && !is.null(params$measures)) {
    measures <- params$measures
    if (!is.vector(measures)) measures <- c(measures)
  }
  
  log_info("Report requested for scenarios: %s", paste(scenarios, collapse = ", "))
  log_info("Selected metrics: %s", paste(metrics, collapse = ", "))
  log_info("Selected measures: %s", paste(measures, collapse = ", "))
  
  # Initialize result containers
  images <- c()
  errors <- c()
  
  # Process the parameters similar to the Python implementation
  scenarios_delimited <- ""
  scenarios_dash <- ""
  
  if (length(scenarios) > 0) {
    scenarios_delimited <- paste(scenarios, collapse = ",")
    scenarios_dash <- paste(scenarios, collapse = "-")
  } else {
    scenarios_delimited <- scenarios
    scenarios_dash <- scenarios
  }
  
  # Set up required directories
  report_dir <- here::here("shrp2c16", "projects", "project", "reports")
  if (!dir.exists(report_dir)) {
    log_info("Creating reports directory: %s", report_dir)
    dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Process each metric and measure combination
  for (metric in metrics) {
    for (measure in measures) {
      # Extract parts from metric (format: <scope>_<type>_<area>)
      metric_parts <- unlist(strsplit(metric, "_"))
      
      if (length(metric_parts) >= 2) {
        # Generate image filename following same convention as Python
        image_filename <- paste0(scenarios_dash, "_", metric_parts[2], "_", metric_parts[1], "_", measure, ".jpeg")
        images <- c(images, image_filename)
        
        # Prepare the working directory - using the Base scenario directory
        scenario_dir <- here::here("shrp2c16", "projects", "project", "Base")
        if (!dir.exists(scenario_dir)) {
          error_msg <- paste("Base scenario directory does not exist:", scenario_dir)
          log_warn(error_msg)
          errors <- c(errors, error_msg)
          next
        }
        
        # Create a simple report file directly
        log_info("Generating report image: %s", image_filename)
        #log_path <- file.path("rpat_reports.log")
        script_path <- here::here("shrp2c16", "scripts", "SmartGAP_Reports.r")

        # Execute in a tryCatch block to handle errors
        tryCatch({
            # Create the system command to run the R script
            cmd_args <- c(shQuote(script_path), 
                          "-s", 
                          shQuote(scenarios_delimited),
                          "-p",
                          shQuote(metric_parts[2]),
                          "-a",
                          shQuote(metric_parts[1]),
                          "-m",
                          shQuote(measure)
                        )
            #log_info(cmd_args)
            # Execute the command and redirect output to sim.log
            # On Mac/Linux, we can use system() with wait=FALSE to run asynchronously
            result <- system2(rscript_cmd, args = cmd_args, stdout = FALSE, stderr = FALSE, wait = TRUE)
            #log_info(result)
        }, error = function(e) {
          # Generate a traceback string
          tb <- paste(capture.output(traceback()), collapse = "\n")
          error_msg <- paste("Error generating report:", conditionMessage(e))
          log_error("%s\nTraceback: %s", error_msg, tb)
          errors <- c(errors, error_msg)
          
          # Return to original directory in case of error
          setwd(original_dir)
        })
      }
    }
  }
 
  # Return JSON similar to Python implementation
  result <- list(
    scenarios = scenarios,
    metrics = metrics,
    images = images
  )
  
  # Add errors if any occurred
  if (length(errors) > 0) {
    result$errors <- errors
  }
  
  return(result)
}

#* @assets ./projects/project/reports /reports
list()

# Define a custom serializer function for the module
serializer_unboxed_json <- function() {
  function(val, req, res, err) {
    res$body <- toJSON(val, auto_unbox = TRUE, pretty = TRUE)
    res
  }
}

#* @get /CSS/*
#* @serializer octet
function(req, res, ...) {
  # Extract the CSS file path from the URL
  path_parts <- list(...)
  css_path <- paste(path_parts, collapse = "/")
  
  # Determine full path of the CSS file
  full_path <- file.path(views_dir, "CSS", css_path)
  
  if (!file.exists(full_path)) {
    log_error("CSS file not found: %s", css_path)
    res$status <- 404
    return(list(error = "CSS file not found"))
  }
  
  # Set content type header
  res$setHeader("Content-Type", "text/css")
  
  # Add Content-Disposition header
  res$setHeader("Content-Disposition", paste0("inline; filename=\"", basename(full_path), "\""))
  
  # Log the file being served
  log_info("Serving CSS file: %s", full_path)
  
  # Return the binary content
  readBin(full_path, "raw", file.info(full_path)$size)
}

#* @get /JScripts/*
#* @serializer octet
function(req, res, ...) {
  # Extract the JS file path from the URL
  path_parts <- list(...)
  js_path <- paste(path_parts, collapse = "/")
  
  # Determine full path of the JS file
  full_path <- file.path(views_dir, "JScripts", js_path)
  
  if (!file.exists(full_path)) {
    log_error("JavaScript file not found: %s", js_path)
    res$status <- 404
    return(list(error = "JavaScript file not found"))
  }
  
  # Set content type header
  res$setHeader("Content-Type", "application/javascript")
  
  # Add Content-Disposition header
  res$setHeader("Content-Disposition", paste0("inline; filename=\"", basename(full_path), "\""))
  
  # Log the file being served
  log_info("Serving JavaScript file: %s", full_path)
  
  # Return the binary content
  readBin(full_path, "raw", file.info(full_path)$size)
}

#* @plumber
#* Configure the plumber API
function(pr) {
    # Set global JSON serializer for all endpoints
    pr %>% 
      pr_set_serializer(serializer_unboxed_json())
    
    # Return the configured API object
    pr
}