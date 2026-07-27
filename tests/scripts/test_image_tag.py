import json
import subprocess
import sys
from pathlib import Path

import pytest

from scripts.image_tag import ImageTagGenerator

ROOT_DIR = Path(__file__).resolve().parent.parent.parent


# --- _validate_tag_level ---


@pytest.mark.parametrize(
	'level,expected',
	[
		('global', 'global'),
		('major', 'major'),
		('minor', 'minor'),
		('patch', 'patch'),
		('bogus', 'patch'),
		('', 'patch'),
	],
)
def test_validate_tag_level(level, expected):
	assert ImageTagGenerator._validate_tag_level(level) == expected


def test_component_defaults_to_patch_when_level_missing():
	gen = ImageTagGenerator(components=[('python', '3.14.6')])
	assert gen.components == [('python', '3.14.6', 'patch', None)]


def test_component_normalizes_invalid_level():
	gen = ImageTagGenerator(components=[('python', '3.14.6', 'bogus')])
	assert gen.components[0][2] == 'patch'


def test_component_keeps_unlabeled_flag():
	gen = ImageTagGenerator(components=[('python', '3.14.6', 'minor', 'always')])
	assert gen.components[0][3] == 'always'


# --- _get_component_options ---


def test_options_empty_version_returns_blank():
	gen = ImageTagGenerator(components=[])
	assert gen._get_component_options('python', '', 'patch') == ['']


def test_options_patch_level():
	gen = ImageTagGenerator(components=[])
	assert gen._get_component_options('python', '3.14.6', 'patch') == ['python3.14.6']


def test_options_minor_level_deduplicates():
	gen = ImageTagGenerator(components=[])
	# 2-part version: "minor" is the same as the raw version, so options collapse
	assert gen._get_component_options('python', '3.14', 'minor') == ['python3.14']


def test_options_minor_level_distinct_parts():
	gen = ImageTagGenerator(components=[])
	assert gen._get_component_options('python', '3.14.6', 'minor') == [
		'python3.14.6',
		'python3.14',
	]


def test_options_major_level():
	gen = ImageTagGenerator(components=[])
	assert gen._get_component_options('python', '3.14.6', 'major') == [
		'python3.14.6',
		'python3.14',
		'python3',
	]


def test_options_global_level_labeled():
	gen = ImageTagGenerator(components=[])
	assert gen._get_component_options('python', '3.14.6', 'global') == [
		'python3.14.6',
		'python3.14',
		'python3',
		'python',
	]


def test_options_global_level_unlabeled_always_drops_package_prefix():
	gen = ImageTagGenerator(components=[])
	options = gen._get_component_options('python', '3.14.6', 'global', 'always')
	assert options == ['3.14.6', '3.14', '3', '']


def test_options_global_level_unlabeled_global_keeps_prefix_but_bare_global_tag():
	gen = ImageTagGenerator(components=[])
	options = gen._get_component_options('python', '3.14.6', 'global', 'global')
	assert options == ['python3.14.6', 'python3.14', 'python3', '']


def test_options_unlabeled_always_on_non_global_level():
	gen = ImageTagGenerator(components=[])
	options = gen._get_component_options('python', '3.14.6', 'minor', 'always')
	assert options == ['3.14.6', '3.14']


# --- generate_tags ---


def test_generate_tags_single_component_patch():
	gen = ImageTagGenerator(components=[('python', '3.14.6', 'patch', None)])
	assert gen.generate_tags() == ['python3.14.6']


def test_generate_tags_no_components_falls_back_to_latest():
	gen = ImageTagGenerator(components=[])
	assert gen.generate_tags() == ['latest']


def test_generate_tags_all_blank_components_falls_back_to_latest():
	gen = ImageTagGenerator(components=[('python', '', 'patch', None)])
	assert gen.generate_tags() == ['latest']


def test_generate_tags_cartesian_product_multiple_components():
	gen = ImageTagGenerator(
		components=[
			('python', '3.14.6', 'major', None),
			('poetry', '2.1.5', 'patch', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == [
		'python3.14.6-poetry2.1.5',
		'python3.14-poetry2.1.5',
		'python3-poetry2.1.5',
	]


def test_generate_tags_only_fully_qualified_forces_patch():
	gen = ImageTagGenerator(components=[('python', '3.14.6', 'global', None)])
	tags = gen.generate_tags(only_fully_qualified=True)
	assert tags == ['python3.14.6']


def test_generate_tags_only_fully_qualified_ignores_multiple_components():
	gen = ImageTagGenerator(
		components=[
			('python', '3.14.6', 'global', None),
			('poetry', '2.1.5', 'major', None),
		]
	)
	tags = gen.generate_tags(only_fully_qualified=True)
	assert tags == ['python3.14.6-poetry2.1.5']


def test_generate_tags_both_components_minor_skips_major_and_global():
	# Neither component asks for more than "minor", so the max scope across
	# components is "minor" and no major/global iterations are produced at all.
	gen = ImageTagGenerator(
		components=[
			('python', '3.14.6', 'minor', None),
			('poetry', '2.1.5', 'minor', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == [
		'python3.14.6-poetry2.1.5',
		'python3.14-poetry2.1',
	]


def test_generate_tags_both_components_patch_stays_single_tag():
	gen = ImageTagGenerator(
		components=[
			('python', '3.14.6', 'patch', None),
			('poetry', '2.1.5', 'patch', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == ['python3.14.6-poetry2.1.5']


def test_generate_tags_doc_example_patch_then_minor_major_global():
	# python is capped at "minor" and freezes there once the wider "uv" component
	# (capped at "global") keeps generalizing further.
	gen = ImageTagGenerator(
		components=[
			('python', '3.10.4', 'minor', None),
			('uv', '0.11.3', 'global', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == [
		'python3.10.4-uv0.11.3',
		'python3.10-uv0.11',
		'python3.10-uv0',
		'python3.10-uv',
	]


def test_generate_tags_three_components_bump_and_freeze():
	gen = ImageTagGenerator(
		components=[
			('python', '3.14.6', 'global', None),
			('poetry', '2.1.5', 'patch', None),
			('uv', '0.11.3', 'patch', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == [
		'python3.14.6-poetry2.1.5-uv0.11.3',
		'python3.14-poetry2.1.5-uv0.11.3',
		'python3-poetry2.1.5-uv0.11.3',
		'python-poetry2.1.5-uv0.11.3',
	]


def test_generate_tags_unlabeled_component_can_be_blank_in_tag():
	gen = ImageTagGenerator(
		components=[
			('python', '3.14.6', 'global', 'always'),
			('poetry', '2.1.5', 'patch', None),
		]
	)
	tags = gen.generate_tags()
	# the blank python option combines with poetry at its patch level, no leading dash
	assert 'poetry2.1.5' in tags
	assert '3.14.6-poetry2.1.5' in tags


def test_image_tags_populated_after_generate():
	gen = ImageTagGenerator(components=[('python', '3.14.6')])
	assert gen.image_tags == []
	gen.generate_tags()
	assert gen.image_tags == ['python3.14.6']


# --- _get_standard_tag / standard tag in generate_tags ---


def test_get_standard_tag_none_for_no_components():
	gen = ImageTagGenerator(components=[])
	assert gen._get_standard_tag() is None


def test_get_standard_tag_elevates_known_components_to_their_standard_level():
	# python defaults to "minor", node defaults to "major".
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'global', None),
			('node', '4.5.6', 'major', None),
		]
	)
	assert gen._get_standard_tag() == 'python1.2-node4'


def test_get_standard_tag_none_when_known_component_requested_narrower_than_standard():
	# python requested at "patch", which is narrower than its "minor" standard.
	gen = ImageTagGenerator(components=[('python', '1.2.3', 'patch', None)])
	assert gen._get_standard_tag() is None


def test_get_standard_tag_none_when_any_known_component_falls_short():
	# node is exactly at its "major" standard, but python is below its "minor"
	# standard, so no standard tag can be built at all.
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'patch', None),
			('node', '4.5.6', 'major', None),
		]
	)
	assert gen._get_standard_tag() is None


def test_get_standard_tag_uses_own_level_for_unknown_component():
	# poetry has no configured standard level, so it keeps its own requested level.
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'global', None),
			('poetry', '2.1.5', 'patch', None),
		]
	)
	assert gen._get_standard_tag() == 'python1.2-poetry2.1.5'


def test_get_standard_tag_respects_custom_standard_levels():
	gen = ImageTagGenerator(
		components=[('poetry', '2.1.5', 'major', None)],
		standard_levels={'poetry': 'minor'},
	)
	assert gen._get_standard_tag() == 'poetry2.1'


def test_generate_tags_appends_standard_tag_for_known_components():
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'global', None),
			('node', '4.5.6', 'major', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == [
		'python1.2.3-node4.5.6',
		'python1.2-node4.5',
		'python1-node4',
		'python-node4',
		'python1.2-node4',
	]


def test_generate_tags_does_not_duplicate_standard_tag_if_already_present():
	# python at "minor" already yields "python3.14" as its most-general option,
	# which is exactly the standard tag value, so nothing extra is appended.
	gen = ImageTagGenerator(components=[('python', '3.14.6', 'minor', None)])
	tags = gen.generate_tags()
	assert tags == ['python3.14.6', 'python3.14']


def test_generate_tags_only_fully_qualified_skips_standard_tag():
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'global', None),
			('node', '4.5.6', 'major', None),
		]
	)
	tags = gen.generate_tags(only_fully_qualified=True)
	assert tags == ['python1.2.3-node4.5.6']


def test_generate_tags_no_standard_tag_when_all_known_components_at_patch():
	# Both python and node are requested at "patch", below both of their
	# standards ("minor" and "major" respectively), so no standard tag is added.
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'patch', None),
			('node', '4.5.6', 'patch', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == ['python1.2.3-node4.5.6']
	assert gen._get_standard_tag() is None


def test_generate_tags_no_standard_tag_when_one_known_component_at_patch():
	# python at "global" satisfies its "minor" standard, but node at "patch"
	# falls short of its "major" standard, so the standard tag is still skipped.
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'global', None),
			('node', '4.5.6', 'patch', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == [
		'python1.2.3-node4.5.6',
		'python1.2-node4.5.6',
		'python1-node4.5.6',
		'python-node4.5.6',
	]
	assert gen._get_standard_tag() is None


def test_generate_tags_standard_tag_appended_last():
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'global', None),
			('node', '4.5.6', 'major', None),
		]
	)
	tags = gen.generate_tags()
	assert tags[-1] == 'python1.2-node4'


def test_generate_tags_no_extra_tag_when_known_component_below_standard():
	# python requested at "patch" (below its "minor" standard), so generate_tags
	# should produce only the regular stepped tags, with nothing appended.
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'patch', None),
			('node', '4.5.6', 'major', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == [
		'python1.2.3-node4.5.6',
		'python1.2.3-node4.5',
		'python1.2.3-node4',
	]


def test_generate_tags_standard_tag_mixed_with_unknown_component():
	# poetry has no configured standard, so it keeps its own requested level
	# ("patch") in the standard tag. Here it coincides with the "minor" step
	# already produced for python, so nothing new is appended.
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'global', None),
			('poetry', '2.1.5', 'patch', None),
		]
	)
	tags = gen.generate_tags()
	assert tags == [
		'python1.2.3-poetry2.1.5',
		'python1.2-poetry2.1.5',
		'python1-poetry2.1.5',
		'python-poetry2.1.5',
	]
	assert gen._get_standard_tag() == 'python1.2-poetry2.1.5'


def test_generate_tags_standard_tag_with_custom_standard_levels():
	# poetry is pinned to "minor" by the custom mapping while uv (unknown to
	# the mapping) keeps its own "global" level, producing a combination that
	# doesn't match any of the regular stepped tags.
	gen = ImageTagGenerator(
		components=[
			('poetry', '2.1.5', 'major', None),
			('uv', '0.11.3', 'global', None),
		],
		standard_levels={'poetry': 'minor'},
	)
	tags = gen.generate_tags()
	assert tags == [
		'poetry2.1.5-uv0.11.3',
		'poetry2.1-uv0.11',
		'poetry2-uv0',
		'poetry2-uv',
		'poetry2.1-uv',
	]
	assert gen._get_standard_tag() == 'poetry2.1-uv'


def test_generate_tags_empty_standard_levels_disables_standard_tag():
	# With an empty standard_levels mapping, every component falls back to its
	# own requested level, so the "standard" tag collapses to the same value as
	# the widest stepped tag and adds nothing new.
	gen = ImageTagGenerator(
		components=[
			('python', '1.2.3', 'global', None),
			('node', '4.5.6', 'major', None),
		],
		standard_levels={},
	)
	tags = gen.generate_tags()
	assert tags == [
		'python1.2.3-node4.5.6',
		'python1.2-node4.5',
		'python1-node4',
		'python-node4',
	]


def test_cli_standard_tag_included_for_known_components():
	result = run_cli(['python=1.2.3:global,node=4.5.6:major'])
	assert result.returncode == 0
	assert result.stdout.splitlines() == [
		'python1.2.3-node4.5.6',
		'python1.2-node4.5',
		'python1-node4',
		'python-node4',
		'python1.2-node4',
	]


# --- print_tags ---


def test_print_tags_compact(capsys):
	gen = ImageTagGenerator(components=[('python', '3.14.6', 'minor')])
	gen.generate_tags()
	gen.print_tags(compact_output=True)
	out = capsys.readouterr().out
	assert out == 'python3.14.6,python3.14\n'


def test_print_tags_multiline(capsys):
	gen = ImageTagGenerator(components=[('python', '3.14.6', 'minor')])
	gen.generate_tags()
	gen.print_tags(compact_output=False)
	out = capsys.readouterr().out
	assert out == 'python3.14.6\npython3.14\n'


# --- CLI behavior (subprocess, exercises argument parsing end-to-end) ---


def run_cli(args, cwd=ROOT_DIR):
	return subprocess.run(
		[sys.executable, '-m', 'scripts.image_tag', *args],
		cwd=cwd,
		capture_output=True,
		text=True,
		check=False,
	)


def test_cli_basic_component():
	result = run_cli(['python=3.14.6:minor'])
	assert result.returncode == 0
	assert result.stdout.splitlines() == ['python3.14.6', 'python3.14']


def test_cli_compact_flag():
	result = run_cli(['-c', 'python=3.14.6:minor'])
	assert result.returncode == 0
	assert result.stdout.strip() == 'python3.14.6,python3.14'


def test_cli_default_tag_level_is_patch():
	result = run_cli(['python=3.14.6'])
	assert result.returncode == 0
	assert result.stdout.strip() == 'python3.14.6'


def test_cli_missing_equals_sign_errors():
	result = run_cli(['python3.14.6'])
	assert result.returncode == 1
	assert 'Invalid component format' in result.stderr


def test_cli_unlabeled_always_flag():
	result = run_cli(['python?=3.14.6:global'])
	assert result.returncode == 0
	lines = result.stdout.splitlines()
	assert '3.14.6' in lines
	# fully unlabeled falls back to the bare 'latest' tag
	assert 'latest' in lines
	assert 'python3.14.6' not in lines


def test_cli_unlabeled_global_flag():
	result = run_cli(['python+=3.14.6:global'])
	assert result.returncode == 0
	lines = result.stdout.splitlines()
	assert 'python3.14.6' in lines
	assert 'latest' in lines


def test_cli_comma_separated_single_arg():
	result = run_cli(['python=3.14.6:minor,poetry=2.1.5'])
	assert result.returncode == 0
	assert result.stdout.splitlines() == [
		'python3.14.6-poetry2.1.5',
		'python3.14-poetry2.1.5',
	]


def test_cli_json_list_single_arg():
	payload = json.dumps(['python=3.14.6:minor', 'poetry=2.1.5'])
	result = run_cli([payload])
	assert result.returncode == 0
	assert result.stdout.splitlines() == [
		'python3.14.6-poetry2.1.5',
		'python3.14-poetry2.1.5',
	]


def test_cli_multiple_positional_components():
	result = run_cli(['python=3.14.6:minor', 'poetry=2.1.5'])
	assert result.returncode == 0
	assert result.stdout.splitlines() == [
		'python3.14.6-poetry2.1.5',
		'python3.14-poetry2.1.5',
	]


def test_cli_no_arguments_errors():
	result = run_cli([])
	assert result.returncode == 2  # argparse usage error
