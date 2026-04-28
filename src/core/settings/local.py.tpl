"""
Local settings overrides — copy to local.py and customise.
This file is gitignored and never committed.
"""
from .dev import *  # noqa: F401, F403

# Uncomment and adjust if your local Postgres credentials differ from defaults:
# DATABASES["default"]["USER"] = "myuser"
# DATABASES["default"]["PASSWORD"] = "mypassword"
# DATABASES["default"]["NAME"] = "wsde"
