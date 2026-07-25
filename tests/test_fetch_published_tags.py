import json
import urllib.error
import urllib.request
from datetime import datetime, timezone

import pytest
import yaml

from scripts.fetch_published_tags import FetchPublishedTags


class FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def read(self):
        return json.dumps(self._payload).encode()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


# --- __init__ ---

def test_init_raises_on_empty_image_name():
    with pytest.raises(ValueError):
        FetchPublishedTags(image_name="")


def test_init_uses_explicit_token(tmp_path):
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="explicit-token",
        output_path=str(tmp_path / "published_tags.yml"),
    )
    assert fetcher.github_read_token == "explicit-token"


def test_init_falls_back_to_env_token(tmp_path, monkeypatch):
    monkeypatch.delenv("GITHUB_TOKEN", raising=False)
    monkeypatch.setenv("GITHUB_READ_TOKEN", "env-token")
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        output_path=str(tmp_path / "published_tags.yml"),
    )
    assert fetcher.github_read_token == "env-token"


def test_init_falls_back_to_github_token_env(tmp_path, monkeypatch):
    monkeypatch.delenv("GITHUB_READ_TOKEN", raising=False)
    monkeypatch.setenv("GITHUB_TOKEN", "fallback-token")
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        output_path=str(tmp_path / "published_tags.yml"),
    )
    assert fetcher.github_read_token == "fallback-token"


def test_init_default_ignore_tags_older_than_is_recent(tmp_path, monkeypatch):
    monkeypatch.delenv("GITHUB_READ_TOKEN", raising=False)
    monkeypatch.delenv("GITHUB_TOKEN", raising=False)
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        output_path=str(tmp_path / "published_tags.yml"),
    )
    assert fetcher.ignore_tags_older_than.tzinfo is not None


# --- fetch_published_tags ---

def test_fetch_without_token_returns_empty_and_warns(tmp_path, monkeypatch, capsys):
    monkeypatch.delenv("GITHUB_READ_TOKEN", raising=False)
    monkeypatch.delenv("GITHUB_TOKEN", raising=False)
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        output_path=str(tmp_path / "published_tags.yml"),
    )
    result = fetcher.fetch_published_tags()
    assert result == set()
    assert "token not provided" in capsys.readouterr().err


def test_fetch_collects_tags_across_pages(tmp_path, monkeypatch):
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="token",
        output_path=str(tmp_path / "published_tags.yml"),
    )

    pages = [
        [
            {"metadata": {"container": {"tags": ["3.14-slim", "3.14"]}}},
            {"metadata": {"container": {"tags": ["3.13"]}}},
        ],
        [],
    ]
    call_count = {"n": 0}

    def fake_urlopen(req, timeout=10):
        idx = call_count["n"]
        call_count["n"] += 1
        return FakeResponse(pages[idx] if idx < len(pages) else [])

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    result = fetcher.fetch_published_tags()
    assert result == {"3.14-slim", "3.14", "3.13"}


def test_fetch_ignores_non_dict_entries(tmp_path, monkeypatch):
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="token",
        output_path=str(tmp_path / "published_tags.yml"),
    )

    pages = [["not-a-dict", {"metadata": {"container": {"tags": ["3.14"]}}}], []]
    call_count = {"n": 0}

    def fake_urlopen(req, timeout=10):
        idx = call_count["n"]
        call_count["n"] += 1
        return FakeResponse(pages[idx] if idx < len(pages) else [])

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    result = fetcher.fetch_published_tags()
    assert result == {"3.14"}


def test_fetch_stops_on_non_list_response(tmp_path, monkeypatch):
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="token",
        output_path=str(tmp_path / "published_tags.yml"),
    )

    def fake_urlopen(req, timeout=10):
        return FakeResponse({"error": "not found"})

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    result = fetcher.fetch_published_tags()
    assert result == set()


def test_fetch_handles_url_error_gracefully(tmp_path, monkeypatch, capsys):
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="token",
        output_path=str(tmp_path / "published_tags.yml"),
    )

    def fake_urlopen(req, timeout=10):
        raise urllib.error.URLError("boom")

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    result = fetcher.fetch_published_tags()
    assert result == set()
    assert "Failed to fetch tags" in capsys.readouterr().err


# --- save_published_tags_file ---

def test_save_overwrite(tmp_path):
    output_path = tmp_path / "published_tags.yml"
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="token",
        output_path=str(output_path),
    )
    fetcher.published_tags = {"3.14", "3.13"}
    fetcher.save_published_tags_file(append=False)

    saved = yaml.safe_load(output_path.read_text())
    assert set(saved["published_tags"]["python-devbox"]) == {"3.14", "3.13"}
    assert "last_updated" in saved


def test_save_append_merges_with_existing(tmp_path):
    output_path = tmp_path / "published_tags.yml"
    output_path.write_text(
        yaml.dump({"published_tags": {"python-devbox": ["3.12"]}})
    )
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="token",
        output_path=str(output_path),
    )
    fetcher.published_tags = {"3.14"}
    fetcher.save_published_tags_file(append=True)

    saved = yaml.safe_load(output_path.read_text())
    assert set(saved["published_tags"]["python-devbox"]) == {"3.12", "3.14"}


def test_save_overwrite_drops_existing_tags_for_same_image(tmp_path):
    output_path = tmp_path / "published_tags.yml"
    output_path.write_text(
        yaml.dump({"published_tags": {"python-devbox": ["3.12"]}})
    )
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="token",
        output_path=str(output_path),
    )
    fetcher.published_tags = {"3.14"}
    fetcher.save_published_tags_file(append=False)

    saved = yaml.safe_load(output_path.read_text())
    assert set(saved["published_tags"]["python-devbox"]) == {"3.14"}


def test_save_preserves_other_image_entries(tmp_path):
    output_path = tmp_path / "published_tags.yml"
    output_path.write_text(
        yaml.dump({"published_tags": {"other-image": ["1.0"]}})
    )
    fetcher = FetchPublishedTags(
        image_name="python-devbox",
        github_read_token="token",
        output_path=str(output_path),
    )
    fetcher.published_tags = {"3.14"}
    fetcher.save_published_tags_file(append=False)

    saved = yaml.safe_load(output_path.read_text())
    assert saved["published_tags"]["other-image"] == ["1.0"]
    assert set(saved["published_tags"]["python-devbox"]) == {"3.14"}
