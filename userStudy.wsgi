#!/usr/bin/python

import os
import sys
import logging

# Ensure the correct Python environment is used inside Docker
venv_path = "/usr/local/lib/python3.11/site-packages"
sys.path.insert(0, venv_path)

# Set up logging
logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

# Set working directory to ensure app imports correctly
sys.path.insert(0, "/var/www/userStudy")

sys.executable = "/usr/local/bin/python3"

# Import and run the Flask app
from userStudy import app as application