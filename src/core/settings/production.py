"""
Production settings for Google App Engine. Extends base.

Secrets are loaded from GCP Secret Manager via the SECRETS dict populated
by core.secrets.load_secrets(), called from manage.py and wsgi/asgi.
"""
import os

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

SECRET_KEY = os.environ["SECRET_KEY"]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ["DB_NAME"],
        "USER": os.environ["DB_USER"],
        "PASSWORD": os.environ["DB_PASSWORD"],
        "HOST": os.environ.get("DB_HOST", "/cloudsql/" + os.environ.get("CLOUD_SQL_CONNECTION_NAME", "")),
        "PORT": os.environ.get("DB_PORT", "5432"),
    }
}

# GCS static files
DEFAULT_FILE_STORAGE = "storages.backends.gcloud.GoogleCloudStorage"
STATICFILES_STORAGE = "storages.backends.gcloud.GoogleCloudStorage"
GS_BUCKET_NAME = os.environ.get("GCS_BUCKET_NAME", "")
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
