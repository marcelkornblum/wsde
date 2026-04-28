"""
Local settings overrides — copy to local.py and customise.
This file is gitignored and never committed.

Prerequisites:
  1. Run 'just proxy-install' (or 'just setup') to download the Cloud SQL Auth Proxy.
  2. Run 'just dev-creds' to retrieve your DB password from Secret Manager.
  3. Run 'just proxy' in a separate terminal to start the proxy on localhost:5432.
"""
from .dev import *  # noqa: F401, F403

# Cloud SQL dev database credentials (run 'just dev-creds' to get the password)
# DATABASES["default"]["NAME"] = "wsde_dev"
# DATABASES["default"]["USER"] = "wsde_dev"
# DATABASES["default"]["PASSWORD"] = "<from just dev-creds>"
