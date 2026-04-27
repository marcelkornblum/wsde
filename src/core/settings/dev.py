"""
Development settings. Extends base.
"""
from .base import *  # noqa: F401, F403

DEBUG = True

ALLOWED_HOSTS = ["localhost", "127.0.0.1", "0.0.0.0"]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": "wsde",
        "USER": "wsde",
        "PASSWORD": "wsde",
        "HOST": "localhost",
        "PORT": "5432",
    }
}

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Disable password validation in dev
AUTH_PASSWORD_VALIDATORS = []
