"""
Production settings for Google App Engine. Extends base.

Sensitive credentials are loaded from GCP Secret Manager via core.secrets.
Non-sensitive config (DB host, bucket name) is read from environment variables
set in app.yaml — safe to commit, not secret.
"""

import os

from core.secrets import get_secret

from .base import *  # noqa: F401, F403

DEBUG = False

ALLOWED_HOSTS = [
    "wsde.rcel.biz",
    "www.wsde.rcel.biz",
    "*.appspot.com",
]

CSRF_TRUSTED_ORIGINS = [
    "https://wsde.rcel.biz",
    "https://www.wsde.rcel.biz",
]

SECRET_KEY = get_secret("SECRET_KEY")

_conn_name = os.environ.get("CLOUD_SQL_CONNECTION_NAME", "wsde-marcelkornblum:europe-west2:wsde-db")
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": get_secret("DB_NAME"),
        "USER": get_secret("DB_USER"),
        "PASSWORD": get_secret("DB_PASSWORD"),
        # DB_HOST is overridden to /tmp/cloudsql/... during CI migrations (Cloud SQL proxy).
        # On GAE at runtime DB_HOST is unset so it falls back to the standard socket path.
        "HOST": os.environ.get("DB_HOST", f"/cloudsql/{_conn_name}"),
        "PORT": "5432",
    }
}

# GCS static files
DEFAULT_FILE_STORAGE = "storages.backends.gcloud.GoogleCloudStorage"
STATICFILES_STORAGE = "storages.backends.gcloud.GoogleCloudStorage"
GS_BUCKET_NAME = os.environ.get("GCS_BUCKET_NAME", "wsde-static")
GS_DEFAULT_ACL = "publicRead"
STATIC_URL: str = f"https://storage.googleapis.com/{GS_BUCKET_NAME}/static/"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
