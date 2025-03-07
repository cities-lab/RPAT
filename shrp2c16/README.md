# RPAT SHRP2C16 Module

## Overview

The SHRP2C16 module is part of the Regional Planning Analysis Tool (RPAT), designed for transportation planning and scenario analysis. This module provides a web-based interface to create, manage, and analyze transportation scenarios through an R-based API backend with a web frontend.

## Features

- Scenario management (create, copy, delete)
- Parameter file editing and management
- Report generation and visualization
- Data import/export capabilities
- Interactive UI for transportation planning

## System Requirements

### R Dependencies
- plumber
- jsonlite
- tools
- httr
- ps
- here
- logger
- fs

## Installation

1. Ensure R is installed on your system
2. Install required R packages:
3. Launch the application by double-clicking RUN_RPAT.command (for macOS) or RUN_RPAT.bat (for Windows)

## Project Structure

```
shrp2c16/
├── gui/
│   ├── app.py             # Python CherryPy server implementation
│   └── views/             # Web UI files
│       ├── docs/          # Documentation files
│       └── scenarios/     # Scenario-specific views
├── projects/
│   ├── Demo Project/      # Template project
│   └── project/           # Active projects directory
│       ├── [scenario]/    # Individual scenario directories
│       └── reports/       # Generated reports
├── plumber_app.R          # R Plumber API implementation
├── run_rpat.R             # R script to start the application
└── README.md              # This file
└── RUN_RPAT.command       # Command to run the application (macOS)
└── RUN_RPAT.bat           # Command to run the application (Windows)
```

## Running the Application

### Using R (Recommended)

1. Navigate to the RPAT directory
2. Run the application with:
```r
Rscript shrp2c16/run_rpat.R
```

This will start the R Plumber server on port 8765 and automatically open your browser to the application.

## API Documentation

The RPAT API provides the following key endpoints:

### Scenarios
- `GET /scenarioes` - List all available scenarios
- `GET /scenarioes_to_copy` - Get scenarios available for copying
- `GET /new_scenario` - Create a new scenario
- `GET /delete_scenario` - Delete an existing scenario

### State Management
- `GET /state_files/:name` - List state files for a scenario
- `GET /get_default_state` - Get the default state
- `GET /set_default_state` - Set the default state

### File Operations
- `GET /loadstatecsvfile` - Load a CSV state file
- `POST /savecsvfile` - Save a CSV file
- `GET /loadcsvfile` - Load a CSV file

### Reports
- `GET /runReport` - Generate and run a report
- `GET /image/:name` - Serve report images

### Execution Control
- `GET /runstatus` - Check the run status
- `GET /run` - Run the RPAT model
- `GET /stoprun` - Stop the running process

## Static File Serving

The application serves static files from the following locations:

- Web UI: `/` serves from `shrp2c16/gui/views/`
- Reports: `/reports` serves from `shrp2c16/projects/project/reports/`
- CSS: `/CSS/` serves CSS files for the web interface
- JavaScript: `/JScripts/` serves JavaScript files
- Images: `/img/` and `/image/` serve image files

## Troubleshooting

- **Application not starting**: Check for existing RPAT processes and kill them
- **Missing scenarios**: Ensure the projects directory structure is correctly set up
- **Report errors**: Check the rpat_api.log file for detailed error information
- **Image display issues**: Verify the image server is running correctly

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

This project is part of the RPAT suite of tools. This version is modified from [the python web GUI version developed by RSG](https://github.com/RSGInc/RPAT) by [Liming Wang](https://github.com/cities-lab/RPAT.git).
