"""
Staging settings for Google App Engine. Extends production.

Targets the staging GAE service and staging Cloud SQL instance.
All secrets are loaded from Secret Manager (same as production) but
the staging GitHub environment's secrets point to staging resources.
"""

from .production import *  # noqa: F401, F403

ALLOWED_HOSTS = [
    "staging-dot-wsde-marcelkornblum.appspot.com",
    "*.appspot.com",
]

CSRF_TRUSTED_ORIGINS = [
    "https://staging-dot-wsde-marcelkornblum.appspot.com",
]
