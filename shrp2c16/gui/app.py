# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "cherrypy",
#     "psutil",
#     "simplejson",
# ]
# ///
# run the script with `uv run gui/app.py from shrp2c16 directory`

import sys
import webbrowser
import csv
import cherrypy

# import cherrypy.wsgiserver.wsgiserver3
# from cherrypy import wsgiserver
from cherrypy.lib.static import serve_file
import os
import os.path
import json
import simplejson
import subprocess
import shutil
from shutil import copytree
from datetime import datetime
import fnmatch
import signal
from threading import Thread
import time
from time import gmtime, strftime, localtime
import psutil

popen = None


class MyApp:
    """Sample request handler class."""

    popen = None

    def scenarioes(self, _):
        scen_path = os.path.join(os.getcwd(), "projects", "project")
        directories = []
        if os.path.exists(scen_path):
            for directory in os.listdir(scen_path):
                if directory != "parameters" and directory != "reports":
                    directories.append(directory)
        else:
            os.makedirs(scen_path)
            directories = os.listdir(scen_path)
        return simplejson.dumps({"scenarios": directories})

    scenarioes.exposed = True

    def scenarioes_to_copy(self, _):
        root_scenarios = []
        root_scenarios.append("template")
        scenarios = []
        scen_path = os.path.join(os.getcwd(), "projects", "project")
        for directory in os.listdir(scen_path):
            if directory != "parameters" and directory != "reports":
                scenarios.append(directory)
        return simplejson.dumps(
            {"root_scenarios": root_scenarios, "scenarios": scenarios}
        )

    scenarioes_to_copy.exposed = True

    def runstatus(self, _):
        with open(os.path.join(os.getcwd(), "stdout.txt"), "r") as f:
            content = f.readline()
        return simplejson.dumps({"output": content})

    runstatus.exposed = True

    def state_files(self, name, _):
        files = os.listdir(
            os.path.join(os.getcwd(), "projects", "project", name, "parameters")
        )
        return simplejson.dumps({"files": files})

    state_files.exposed = True

    def open_output_directory(self, name, _):
        webbrowser.open(name)
        return simplejson.dumps({"success": "true"})

    open_output_directory.exposed = True

    def output_directories(self, name, _):
        directory = os.path.join(os.getcwd(), "projects", "project", name, "outputs")
        if not os.path.exists(directory):
            os.makedirs(directory)
        files = os.listdir(directory)

        return simplejson.dumps({"files": files, "directory": directory})

    output_directories.exposed = True

    def output_files(self, name, _):
        directory = os.path.join(os.getcwd(), "projects", "project", name, "outputs")
        if not os.path.exists(directory):
            os.makedirs(directory)
        files = os.listdir(directory)
        return simplejson.dumps({"files": files})

    output_files.exposed = True

    def scenario(self, name, _):
        files = os.listdir(
            os.path.join(os.getcwd(), "projects", "project", name, "inputs")
        )
        file_edits = [False for file in files]
        return simplejson.dumps({"files": files, "file_edits": file_edits})

    scenario.exposed = True

    def get_default_state(self, _):
        state = None
        path = os.path.join(os.getcwd(), "state.txt")
        if os.path.exists(path):
            with open(path, "r") as f:
                state = f.readlines()
        return simplejson.dumps({"state": state})

    get_default_state.exposed = True

    def set_default_state(self, state, _):
        state_file = open(os.path.join(os.getcwd(), "state.txt"), "w")
        state_file.write(state)
        state_file.close()

    set_default_state.exposed = True

    def new_scenario(self, name, fromScenario, isFirst, _):
        newdir = os.path.join(os.getcwd(), "projects", "project", name)
        if not os.path.isdir(newdir):
            if fromScenario.startswith("template"):
                copytree(
                    os.path.join(os.getcwd(), "projects", "Demo Project", "base"),
                    os.path.join(os.getcwd(), "projects", "project", name),
                )
            else:
                copytree(
                    os.path.join(os.getcwd(), "projects", "project", fromScenario),
                    os.path.join(os.getcwd(), "projects", "project", name),
                )
            timestamp_file = open(
                os.path.join(os.getcwd(), "projects", "project", name, "time.txt"),
                "w",
            )
            timestamp_file.write(strftime("%a %b %d %H:%M:%S %Y", localtime()))
            timestamp_file.close()
            return simplejson.dumps({"success": True})
        else:
            return simplejson.dumps({"success": False})

    new_scenario.exposed = True

    def delete_scenario(self, name, _):
        shutil.rmtree(os.path.join(os.getcwd(), "projects", "project", name))
        try:
            shutil.rmtree(os.path.join(os.getcwd(), "gui", "views", "scenarios", name))
        except:
            pass
        return simplejson.dumps({"success": True})

    delete_scenario.exposed = True

    def loadTextFile(self, name, fileName, _):
        out = [
            [line.strip()]
            for line in open(
                os.path.join(os.getcwd(), "scenarios", name, "inputs", fileName)
            )
        ]
        return json.dumps({"data": out})

    loadTextFile.exposed = True

    def loadoutputcsvfile(self, name, fileName, _):
        with open(
            os.path.join(os.getcwd(), "projects", "project", name, "outputs", fileName)
        ) as csvfile:
            filereader = csv.reader(csvfile)
            out = [rowItem for rowItem in filereader]
        return json.dumps({"data": out})

    loadoutputcsvfile.exposed = True

    def load_documentation(self, filename, _):
        out = ""
        for line in open(
            os.path.join(os.getcwd(), "gui", "views", "docs", filename), encoding="utf8"
        ):
            out += line
        return json.dumps({"data": out})

    load_documentation.exposed = True

    def loadcsvfile(self, name, fileName, _):
        with open(
            os.path.join(os.getcwd(), "projects", "project", name, "inputs", fileName)
        ) as csvfile:
            filereader = csv.reader(csvfile)
            out = [rowItem for rowItem in filereader]
        return json.dumps({"data": out})

    loadcsvfile.exposed = True

    def loadstatetextfile(self, name, fileName, directory, _):
        path_components = [os.getcwd(), "model", "states", name]
        if directory != "root":
            path_components.append(directory)
        path_components.append(fileName)
        out = [[line.strip()] for line in open(os.path.join(*path_components))]
        return json.dumps({"data": out})

    loadstatetextfile.exposed = True

    def loadReportSettings(self, _):
        with open(os.path.join(os.getcwd(), "scripts", "outputs.csv")) as csvfile:
            filereader = csv.reader(csvfile)
            out = [rowItem for rowItem in filereader]
        return json.dumps({"data": out})

    loadReportSettings.exposed = True

    def runReport(self, **kw):
        scenarios = kw.pop("scenarios[]", [])
        scenarios_delimited = ""
        scenarios_dash = ""

        if isinstance(scenarios, list):
            scenarios_delimited = ",".join([x for x in scenarios])
            scenarios_dash = "-".join([x for x in scenarios])
        else:
            scenarios_delimited = scenarios
            scenarios_dash = scenarios

        passinmetrics = kw.pop("metrics[]", [])
        metrics = []
        if isinstance(passinmetrics, list):
            metrics = passinmetrics
        else:
            metrics.append(passinmetrics)

        measures = []
        passinmeasure = kw.pop("measures[]", [])

        if isinstance(passinmeasure, list):
            measures = passinmeasure
        else:
            measures.append(passinmeasure)
        test = []
        images = []
        for metric in metrics:
            for measure in measures:
                metric_array = metric.split("_")
                images.append(
                    scenarios_dash
                    + "_"
                    + metric_array[1]
                    + "_"
                    + metric_array[0]
                    + "_"
                    + measure
                    + ".jpeg"
                )
                print(scenarios_delimited, metric_array[1], metric_array[0], measure)
                with open(os.path.join(os.getcwd(), "reports.log"), "a") as log_file:
                    MyApp.popen = subprocess.Popen(
                        [
                            "Rscript",
                            os.path.join("scripts", "SmartGAP_Reports.r"),
                            "-s",
                            scenarios_delimited,
                            "-p",
                            metric_array[1],
                            "-a",
                            metric_array[0],
                            "-m",
                            measure,
                        ],
                        cwd=os.getcwd(),
                        stdout=log_file,
                        stderr=subprocess.STDOUT,
                    )
                    MyApp.popen.wait()

        return json.dumps(
            {"scenarios": scenarios, "metrics": metrics, "images": images, "test": test}
        )  # , 'test':test})

    runReport.exposed = True

    def loadstatecsvfile(self, fileName, directory, name, _):
        with open(
            os.path.join(
                os.getcwd(), "projects", "project", name, "parameters", fileName
            )
        ) as csvfile:
            filereader = csv.reader(csvfile)
            out = [rowItem for rowItem in filereader]
        return json.dumps({"data": out})

    loadstatecsvfile.exposed = True

    def savecsvfile(self, data, name, fileName):
        data = simplejson.loads(data)
        with open(
            os.path.join(os.getcwd(), "projects", "project", name, "inputs", fileName),
            "w",
            newline="",
        ) as csvfile:
            filewriter = csv.writer(csvfile)
            filewriter.writerows(data)
        return simplejson.dumps({"success": True})

    savecsvfile.exposed = True

    def saveTextFile(self, data, name, fileName):
        data = simplejson.loads(data)
        with open(
            os.path.join(os.getcwd(), "scenarios", name, "inputs", fileName), "wb"
        ) as file:
            for line in data:
                file.write(line[0] + "\n")
        return simplejson.dumps({"success": True})

    saveTextFile.exposed = True

    def savestatetextfile(self, data, name, fileName, directory):
        path_components = [os.getcwd(), "model", "states", name]
        if directory != "root":
            path_components.append(directory)
        path_components.append(fileName)

        data = simplejson.loads(data)
        with open(
            os.path.join(*path_components),
            "wb",
        ) as file:
            for line in data:
                file.write(line[0] + "\n")

        return simplejson.dumps({"success": True})

    savestatetextfile.exposed = True

    def savestatecsvfile(self, data, name, fileName, directory):
        data = simplejson.loads(data)
        with open(
            os.path.join(
                os.getcwd(), "projects", "project", name, "parameters", fileName
            ),
            "w",
            newline="",
        ) as csvfile:
            filewriter = csv.writer(csvfile)
            filewriter.writerows(data)
        return simplejson.dumps({"success": True})

    savestatecsvfile.exposed = True

    def resetrunstatus(self, _):
        my_stdout_file = open(os.path.join(os.getcwd(), "stdout.txt"), "w", newline="")
        my_stdout_file.write("pending")
        my_stdout_file.close()
        return simplejson.dumps({"Status": "Success"})

    resetrunstatus.exposed = True

    def startrun(self, name, _):
        MyApp.popen = subprocess.Popen(
            [
                "Rscript",
                os.path.join("scripts", "SmartGAP.r"),
                "-s",
                name,
            ],
            stdout=subprocess.PIPE,
            cwd=os.getcwd(),
            stderr=subprocess.STDOUT,
        )
        log_file_name = os.path.join(os.getcwd(), "sim.log")
        my_stdout_file = open(log_file_name, "w")
        my_stdout_file.close()
        for line in iter(MyApp.popen.stdout.readline, ""):
            my_stdout_file = open(log_file_name, "ab")
            my_stdout_file.write(line)
            my_stdout_file.close()

        return simplejson.dumps({"pid": MyApp.popen.pid})

    startrun.exposed = True

    def stoprun(self, _):
        os.system("taskkill /F /T /pid " + str(MyApp.popen.pid))
        my_stdout_file = open(os.path.join(os.getcwd(), "stdout.txt"), "w")
        my_stdout_file.close()
        return simplejson.dumps({"success": 1})

    stoprun.exposed = True

    def exit(self, _):
        raise SystemExit(0)

    exit.exposed = True


# Kill existing processes
for proc in psutil.process_iter():
    pinfo = proc.as_dict(attrs=["pid", "name"])
    procname = str(pinfo["name"])
    procpid = str(pinfo["pid"])
    if "RPAT.exe" in procname and procpid != str(os.getpid()):
        print("Stopped Python Process ", proc)
        proc.kill()


dir = os.getcwd()
report_dir = os.path.join(os.getcwd(), "projects", "project", "reports")
my_stdout_file = open(os.path.join(os.getcwd(), "stdout.txt"), "w")
my_stdout_file.close()

config = {
    "/": {
        "tools.staticdir.on": True,
        "tools.staticdir.dir": os.path.join(dir, "gui", "views"),
        "tools.staticdir.index": "index.html",
    },
    "/reports": {"tools.staticdir.on": True, "tools.staticdir.dir": report_dir},
}
cherrypy.tree.mount(MyApp(), "/", config=config)
cherrypy.server.socket_port = 8765
cherrypy.engine.start()
webbrowser.open_new_tab("http://127.0.0.1:8765/index.html")
cherrypy.engine.block()
