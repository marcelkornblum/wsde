"""
Staging settings for Google App Engine. Extends production.

Targets the staging GAE service and staging Cloud SQL instance.
Secrets are loaded from Secret Manager using _STAGING-suffixed names,
keeping staging credentials fully separate from production.

Required Secret Manager secrets (same project, different names):
  SECRET_KEY_STAGING, DB_NAME_STAGING, DB_USER_STAGING, DB_PASSWORD_STAGING
"""
import os

from core.secrets import get_secret

from .production import *  # noqa: F401, F403

ALLOWED_HOSTS = [
    "staging-dot-wsde-marcelkornblum.appspot.com",
    "*.appspot.com",
]

CSRF_TRUSTED_ORIGINS = [
    "https://staging-dot-wsde-marcelkornblum.appspot.com",
]

# Override production secrets with staging-specific ones
SECRET_KEY = get_secret("SECRET_KEY_STAGING")

_conn_name = os.environ.get("CLOUD_SQL_CONNECTION_NAME", "wsde-marcelkornblum:europe-west2:wsde-db-staging")
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": get_secret("DB_NAME_STAGING"),
        "USER": get_secret("DB_USER_STAGING"),
        "PASSWORD": get_secret("DB_PASSWORD_STAGING"),
        "HOST": f"/cloudsql/{_conn_name}",
        "PORT": "5432",
    }
}
