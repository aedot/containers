#!/bin/bash
# Runit service script for auto-m4b-tool

# Redirect both stdout and stderr to log file
exec /auto-m4b-tool.sh 2>&1 | tee /config/auto-m4b-tool.log
