"""
Development settings. Extends base.

DB connection is configurable via environment variables so this settings
module can also be used in CI (GitHub Actions with a postgres service container).
"""

import os

from .base import *  # noqa: F401, F403

DEBUG = True

ALLOWED_HOSTS = ["localhost", "127.0.0.1", "0.0.0.0"]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("DB_NAME", "wsde"),
        "USER": os.environ.get("DB_USER", "wsde"),
        "PASSWORD": os.environ.get("DB_PASSWORD", "wsde"),
        "HOST": os.environ.get("DB_HOST", "localhost"),
        "PORT": os.environ.get("DB_PORT", "5432"),
    }
}

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Disable password validation in dev
AUTH_PASSWORD_VALIDATORS = []
