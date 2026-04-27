#!/usr/bin/env python
import os
import sys

# src/ layout: add src/ to sys.path so Django can find apps when running manage.py
# from the repo root. (pytest handles this via pythonpath in pyproject.toml.)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "src"))


def main() -> None:
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "core.settings.dev")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH? Did you forget to activate a "
            "virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
