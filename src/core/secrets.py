"""
GCP Secret Manager loader for production settings.

On GAE, GOOGLE_CLOUD_PROJECT is set automatically by the runtime.
On local dev, production.py (the only importer) is never loaded.
"""

import os
from functools import cache

from google.cloud import secretmanager

_DEFAULT_PROJECT_ID = "wsde-marcelkornblum"


@cache
def _client() -> secretmanager.SecretManagerServiceClient:
    return secretmanager.SecretManagerServiceClient()


def get_secret(name: str, version: str = "latest") -> str:
    """Fetch a secret value from GCP Secret Manager."""
    project_id = os.environ.get("GOOGLE_CLOUD_PROJECT", _DEFAULT_PROJECT_ID)
    path = f"projects/{project_id}/secrets/{name}/versions/{version}"
    response = _client().access_secret_version(request={"name": path})
    return response.payload.data.decode("UTF-8")
