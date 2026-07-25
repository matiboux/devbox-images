import json
import subprocess
import sys
from pathlib import Path

import pytest

from scripts.image_tag import ImageTagGenerator

ROOT_DIR = Path(__file__).resolve().parent.parent


# --- _validate_tag_level ---

@pytest.mark.parametrize(
    "level,expected",
    [
        ("global", "global"),
        ("major", "major"),
        ("minor", "minor"),
        ("patch", "patch"),
        ("bogus", "patch"),
        ("", "patch"),
    ],
)
def test_validate_tag_level(level, expected):
    assert ImageTagGenerator._validate_tag_level(level) == expected


def test_component_defaults_to_patch_when_level_missing():
    gen = ImageTagGenerator(components=[("python", "3.14.6")])
    assert gen.components == [("python", "3.14.6", "patch", None)]


def test_component_normalizes_invalid_level():
    gen = ImageTagGenerator(components=[("python", "3.14.6", "bogus")])
    assert gen.components[0][2] == "patch"


def test_component_keeps_unlabeled_flag():
    gen = ImageTagGenerator(components=[("python", "3.14.6", "minor", "always")])
    assert gen.components[0][3] == "always"


# --- _get_component_options ---

def test_options_empty_version_returns_blank():
    gen = ImageTagGenerator(components=[])
    assert gen._get_component_options("python", "", "patch") == [""]


def test_options_patch_level():
    gen = ImageTagGenerator(components=[])
    assert gen._get_component_options("python", "3.14.6", "patch") == ["python3.14.6"]


def test_options_minor_level_deduplicates():
    gen = ImageTagGenerator(components=[])
    # 2-part version: "minor" equals the raw version, so options collapse
    assert gen._get_component_options("python", "3.14", "minor") == ["python3.14"]


def test_options_minor_level_distinct_parts():
    gen = ImageTagGenerator(components=[])
    assert gen._get_component_options("python", "3.14.6", "minor") == [
        "python3.14.6",
        "python3.14",
    ]


def test_options_major_level():
    gen = ImageTagGenerator(components=[])
    assert gen._get_component_options("python", "3.14.6", "major") == [
        "python3.14.6",
        "python3.14",
        "python3",
    ]


def test_options_global_level_labeled():
    gen = ImageTagGenerator(components=[])
    assert gen._get_component_options("python", "3.14.6", "global") == [
        "python3.14.6",
        "python3.14",
        "python3",
        "python",
    ]


def test_options_global_level_unlabeled_always_drops_package_prefix():
    gen = ImageTagGenerator(components=[])
    options = gen._get_component_options("python", "3.14.6", "global", "always")
    assert options == ["3.14.6", "3.14", "3", ""]


def test_options_global_level_unlabeled_global_keeps_prefix_but_bare_global_tag():
    gen = ImageTagGenerator(components=[])
    options = gen._get_component_options("python", "3.14.6", "global", "global")
    assert options == ["python3.14.6", "python3.14", "python3", ""]


def test_options_unlabeled_always_on_non_global_level():
    gen = ImageTagGenerator(components=[])
    options = gen._get_component_options("python", "3.14.6", "minor", "always")
    assert options == ["3.14.6", "3.14"]


# --- generate_tags ---

def test_generate_tags_single_component_patch():
    gen = ImageTagGenerator(components=[("python", "3.14.6", "patch", None)])
    assert gen.generate_tags() == ["python3.14.6"]


def test_generate_tags_no_components_falls_back_to_latest():
    gen = ImageTagGenerator(components=[])
    assert gen.generate_tags() == ["latest"]


def test_generate_tags_all_blank_components_falls_back_to_latest():
    gen = ImageTagGenerator(components=[("python", "", "patch", None)])
    assert gen.generate_tags() == ["latest"]


def test_generate_tags_cartesian_product_multiple_components():
    gen = ImageTagGenerator(
        components=[
            ("python", "3.14.6", "major", None),
            ("poetry", "2.1.5", "patch", None),
        ]
    )
    tags = gen.generate_tags()
    assert tags == [
        "python3.14.6-poetry2.1.5",
        "python3.14-poetry2.1.5",
        "python3-poetry2.1.5",
    ]


def test_generate_tags_only_fully_qualified_forces_patch():
    gen = ImageTagGenerator(
        components=[("python", "3.14.6", "global", None)]
    )
    tags = gen.generate_tags(only_fully_qualified=True)
    assert tags == ["python3.14.6"]


def test_generate_tags_unlabeled_component_can_be_blank_in_tag():
    gen = ImageTagGenerator(
        components=[
            ("python", "3.14.6", "global", "always"),
            ("poetry", "2.1.5", "patch", None),
        ]
    )
    tags = gen.generate_tags()
    # blank python option ('') combined with poetry2.1.5 -> "poetry2.1.5" (no leading dash)
    assert "poetry2.1.5" in tags
    assert "3.14.6-poetry2.1.5" in tags


def test_image_tags_populated_after_generate():
    gen = ImageTagGenerator(components=[("python", "3.14.6")])
    assert gen.image_tags == []
    gen.generate_tags()
    assert gen.image_tags == ["python3.14.6"]


# --- print_tags ---

def test_print_tags_compact(capsys):
    gen = ImageTagGenerator(components=[("python", "3.14.6", "minor")])
    gen.generate_tags()
    gen.print_tags(compact_output=True)
    out = capsys.readouterr().out
    assert out == "python3.14.6,python3.14\n"


def test_print_tags_multiline(capsys):
    gen = ImageTagGenerator(components=[("python", "3.14.6", "minor")])
    gen.generate_tags()
    gen.print_tags(compact_output=False)
    out = capsys.readouterr().out
    assert out == "python3.14.6\npython3.14\n"


# --- CLI behavior (subprocess, exercises argument parsing end-to-end) ---

def run_cli(args, cwd=ROOT_DIR):
    return subprocess.run(
        [sys.executable, "-m", "scripts.image_tag", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
    )


def test_cli_basic_component():
    result = run_cli(["python=3.14.6:minor"])
    assert result.returncode == 0
    assert result.stdout.splitlines() == ["python3.14.6", "python3.14"]


def test_cli_compact_flag():
    result = run_cli(["-c", "python=3.14.6:minor"])
    assert result.returncode == 0
    assert result.stdout.strip() == "python3.14.6,python3.14"


def test_cli_default_tag_level_is_patch():
    result = run_cli(["python=3.14.6"])
    assert result.returncode == 0
    assert result.stdout.strip() == "python3.14.6"


def test_cli_missing_equals_sign_errors():
    result = run_cli(["python3.14.6"])
    assert result.returncode == 1
    assert "Invalid component format" in result.stderr


def test_cli_unlabeled_always_flag():
    result = run_cli(["python?=3.14.6:global"])
    assert result.returncode == 0
    lines = result.stdout.splitlines()
    assert "3.14.6" in lines
    # blank option (fully unlabeled) falls back to the bare 'latest' tag
    assert "latest" in lines
    assert "python3.14.6" not in lines


def test_cli_unlabeled_global_flag():
    result = run_cli(["python+=3.14.6:global"])
    assert result.returncode == 0
    lines = result.stdout.splitlines()
    assert "python3.14.6" in lines
    assert "latest" in lines


def test_cli_comma_separated_single_arg():
    result = run_cli(["python=3.14.6:minor,poetry=2.1.5"])
    assert result.returncode == 0
    assert result.stdout.splitlines() == [
        "python3.14.6-poetry2.1.5",
        "python3.14-poetry2.1.5",
    ]


def test_cli_json_list_single_arg():
    payload = json.dumps(["python=3.14.6:minor", "poetry=2.1.5"])
    result = run_cli([payload])
    assert result.returncode == 0
    assert result.stdout.splitlines() == [
        "python3.14.6-poetry2.1.5",
        "python3.14-poetry2.1.5",
    ]


def test_cli_multiple_positional_components():
    result = run_cli(["python=3.14.6:minor", "poetry=2.1.5"])
    assert result.returncode == 0
    assert result.stdout.splitlines() == [
        "python3.14.6-poetry2.1.5",
        "python3.14-poetry2.1.5",
    ]


def test_cli_no_arguments_errors():
    result = run_cli([])
    assert result.returncode == 2  # argparse usage error
