#!/bin/sh
# Common Setup, DO NOT MODIFY
cd /app
set -e

# COMPLETE THE FOLLOWING SECTIONS
###############################################
# PROJECT DEPENDENCIES AND CONFIGURATION
###############################################
# TODO: Install project dependencies if needed based on relevant config/lock files in the repo.
# Note that we are developing the project, even if dependencies have been installed before, we need to install again to accommodate the changes we made.
# Install python dependencies and packages
pip install -U pip setuptools wheel

# Install core packages
pip install -r projects/vdk-core/requirements.txt
pip install -e projects/vdk-core

pip install -r projects/vdk-control-cli/requirements.txt
pip install -e projects/vdk-control-cli

pip install -r projects/vdk-heartbeat/requirements.txt
pip install -e projects/vdk-heartbeat

# Install all plugins in editable mode
for plugin in projects/vdk-plugins/*; do
    if [ -f "$plugin/setup.py" ]; then
        if [ -f "$plugin/requirements.txt" ]; then
            pip install -r "$plugin/requirements.txt"
        fi
        pip install -e "$plugin"
    fi
done

# TODO: Configure project and environment variables
export PIP_EXTRA_INDEX_URL=${PIP_EXTRA_INDEX_URL:-https://pypi.org/simple}

###############################################
# BUILD
###############################################
echo "================= 0909 BUILD START 0909 ================="
# No additional build steps are required for this Python project.
echo "All packages installed in editable mode."
echo "================= 0909 BUILD END 0909 ================="
