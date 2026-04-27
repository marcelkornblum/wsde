"""Tests for core.secrets — GCP Secret Manager loader."""
from unittest.mock import MagicMock, patch

import pytest


@pytest.fixture(autouse=True)
def clear_lru_cache():
    """Clear the _client lru_cache before each test."""
    from core import secrets

    secrets._client.cache_clear()
    yield
    secrets._client.cache_clear()


def _make_mock_client(secret_value: bytes) -> MagicMock:
    mock_response = MagicMock()
    mock_response.payload.data = secret_value
    mock_client = MagicMock()
    mock_client.access_secret_version.return_value = mock_response
    return mock_client


class TestGetSecret:
    def test_returns_decoded_secret_value(self, monkeypatch):
        monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "test-project")
        mock_client = _make_mock_client(b"my-secret-value")

        with patch("core.secrets._client", return_value=mock_client):
            from core.secrets import get_secret

            result = get_secret("MY_SECRET")

        assert result == "my-secret-value"

    def test_builds_correct_secret_path(self, monkeypatch):
        monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "test-project")
        mock_client = _make_mock_client(b"value")

        with patch("core.secrets._client", return_value=mock_client):
            from core.secrets import get_secret

            get_secret("MY_SECRET")

        mock_client.access_secret_version.assert_called_once_with(
            request={"name": "projects/test-project/secrets/MY_SECRET/versions/latest"}
        )

    def test_uses_specified_version(self, monkeypatch):
        monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "test-project")
        mock_client = _make_mock_client(b"versioned")

        with patch("core.secrets._client", return_value=mock_client):
            from core.secrets import get_secret

            get_secret("MY_SECRET", version="3")

        mock_client.access_secret_version.assert_called_once_with(
            request={"name": "projects/test-project/secrets/MY_SECRET/versions/3"}
        )

    def test_uses_google_cloud_project_env_var(self, monkeypatch):
        monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "my-gcp-project")
        mock_client = _make_mock_client(b"val")

        with patch("core.secrets._client", return_value=mock_client):
            from core.secrets import get_secret

            get_secret("SOME_SECRET")

        call_args = mock_client.access_secret_version.call_args
        assert "my-gcp-project" in call_args.kwargs["request"]["name"]

    def test_falls_back_to_default_project_id(self, monkeypatch):
        monkeypatch.delenv("GOOGLE_CLOUD_PROJECT", raising=False)
        mock_client = _make_mock_client(b"val")

        with patch("core.secrets._client", return_value=mock_client):
            from core.secrets import get_secret

            get_secret("SOME_SECRET")

        call_args = mock_client.access_secret_version.call_args
        assert "wsde-marcelkornblum" in call_args.kwargs["request"]["name"]
