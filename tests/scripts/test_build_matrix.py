import json

import pytest
import yaml

from scripts.build_matrix import BuildMatrix


def write_yaml(path, data):
	path.write_text(yaml.dump(data, sort_keys=False))


def make_versions_file(tmp_path, detected_versions, latest_version=None):
	path = tmp_path / 'versions.yml'
	write_yaml(
		path,
		{
			'detected_versions': detected_versions,
			'latest_version': latest_version or {},
		},
	)
	return str(path)


def make_matrix(
	tmp_path, packages, detected_versions, latest_version=None, constraints=None, **kwargs
):
	versions_path = make_versions_file(tmp_path, detected_versions, latest_version)
	kwargs.setdefault('published_tags_path', str(tmp_path / 'published_tags.yml'))
	kwargs.setdefault('output_path', str(tmp_path / 'build_matrix.yml'))
	constraints_path = tmp_path / 'constraints.yml'
	write_yaml(constraints_path, constraints or {})
	kwargs.setdefault('constraints_path', str(constraints_path))
	return BuildMatrix(
		packages=packages,
		versions_path=versions_path,
		**kwargs,
	)


# --- __init__ ---


def test_init_raises_without_packages():
	with pytest.raises(ValueError):
		BuildMatrix(packages=[])


def test_init_raises_when_all_packages_blank():
	with pytest.raises(ValueError):
		BuildMatrix(packages=['  ', ''])


def test_init_missing_versions_file_raises(tmp_path):
	with pytest.raises(FileNotFoundError):
		BuildMatrix(
			packages=['python'],
			versions_path=str(tmp_path / 'missing.yml'),
		)


def test_init_normalizes_case_and_whitespace(tmp_path):
	bm = make_matrix(tmp_path, ['  Python  '], {'python': ['3.14.6']})
	assert bm.packages == ['python']


def test_init_strips_unlabeled_flag(tmp_path):
	bm = make_matrix(tmp_path, ['python?'], {'python': ['3.14.6']})
	assert bm.packages == ['python']
	assert bm.unlabeled_packages == {'python'}
	assert bm.ghost_packages == set()


def test_init_strips_ghost_flag(tmp_path):
	bm = make_matrix(tmp_path, ['nvm+'], {'nvm': ['0.40.0']})
	assert bm.packages == ['nvm']
	assert bm.ghost_packages == {'nvm'}


def test_init_strips_combined_flags(tmp_path):
	bm = make_matrix(tmp_path, ['python?+'], {'python': ['3.14.6']})
	assert bm.packages == ['python']
	assert bm.unlabeled_packages == {'python'}
	assert bm.ghost_packages == {'python'}


# --- _get_component_tag_level / _get_component_unlabeled_flag ---


def test_component_tag_level_global_when_matches_latest(tmp_path):
	bm = make_matrix(tmp_path, ['python'], {'python': ['3.14.6']})
	assert (
		bm._get_component_tag_level({'python': '3.14.6'}, {'python': '3.14.6'}, 'python')
		== 'global'
	)


def test_component_tag_level_minor_when_not_latest(tmp_path):
	bm = make_matrix(tmp_path, ['python'], {'python': ['3.14.6', '3.13.9']})
	assert (
		bm._get_component_tag_level({'python': '3.13.9'}, {'python': '3.14.6'}, 'python') == 'minor'
	)


def test_component_tag_level_minor_when_package_missing(tmp_path):
	bm = make_matrix(tmp_path, ['python'], {'python': ['3.14.6']})
	assert bm._get_component_tag_level({}, {'python': '3.14.6'}, 'python') == 'minor'


def test_component_tag_level_major_for_non_latest_node(tmp_path):
	# node's own standard level is 'major': even a non-latest but still
	# supported (e.g. EOL) major version qualifies for the 'major' level,
	# since it's already the best patch within its own major bucket.
	bm = make_matrix(tmp_path, ['node'], {'node': ['26.0.0', '20.11.0']})
	assert (
		bm._get_component_tag_level({'node': '20.11.0'}, {'node': '26.0.0'}, 'node') == 'major'
	)


def test_component_tag_level_global_for_static_pseudo_version(tmp_path):
	# A package whose "version" is literally its own name (e.g. 'docker',
	# see DetectVersions._return_static_package) always "matches latest"
	# and falls into the 'global' branch above, so the tag-generation
	# pipeline also emits an alias with that component omitted entirely.
	bm = make_matrix(tmp_path, ['docker'], {'docker': ['docker']})
	assert (
		bm._get_component_tag_level({'docker': 'docker'}, {'docker': 'docker'}, 'docker')
		== 'global'
	)


def test_component_unlabeled_flag_always(tmp_path):
	bm = make_matrix(tmp_path, ['python?'], {'python': ['3.14.6']})
	assert bm._get_component_unlabeled_flag('python') == 'always'


def test_component_unlabeled_flag_global(tmp_path):
	bm = make_matrix(tmp_path, ['nvm+'], {'nvm': ['0.40.0']})
	assert bm._get_component_unlabeled_flag('nvm') == 'global'


def test_component_unlabeled_flag_none(tmp_path):
	bm = make_matrix(tmp_path, ['poetry'], {'poetry': ['2.1.5']})
	assert bm._get_component_unlabeled_flag('poetry') is None


# --- generate_build_matrix ---


def test_generate_build_matrix_missing_package_versions_exits(tmp_path, capsys):
	bm = make_matrix(tmp_path, ['poetry'], {'python': ['3.14.6']})
	with pytest.raises(SystemExit) as excinfo:
		bm.generate_build_matrix(skip_published_tags=False)
	assert excinfo.value.code == 1
	assert "No detected versions found for package 'poetry'" in capsys.readouterr().err


def test_generate_build_matrix_single_package_no_variants(tmp_path):
	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.1.5', '2.0.0']},
		latest_version={'poetry': '2.1.5'},
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	tags = {e['image_tag'] for e in matrix}
	assert tags == {'poetry2.1.5', 'poetry2.0.0'}


def test_generate_build_matrix_build_args_contains_uppercased_versions(tmp_path):
	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.1.5']},
		latest_version={'poetry': '2.1.5'},
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	build_args = json.loads(matrix[0]['build_args'])
	assert build_args == ['POETRY_VERSION=2.1.5']


def test_generate_build_matrix_python_defaults_to_base_only(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python'],
		{'python': ['3.14.6']},
		latest_version={'python': '3.14.6'},
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	tags = {e['image_tag'] for e in matrix}
	assert tags == {'python3.14.6'}


def test_generate_build_matrix_python_base_variants(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python'],
		{'python': ['3.14.6']},
		latest_version={'python': '3.14.6'},
		base_variants=['', 'slim', 'alpine'],
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	tags = {e['image_tag'] for e in matrix}
	assert tags == {
		'python3.14.6',
		'python3.14.6-slim',
		'python3.14.6-alpine',
	}


def test_generate_build_matrix_base_variants_filtered_by_selection(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python'],
		{'python': ['3.14.6']},
		latest_version={'python': '3.14.6'},
		base_variants=['slim'],
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	tags = {e['image_tag'] for e in matrix}
	assert tags == {'python3.14.6-slim'}


def test_generate_build_matrix_base_variants_ignored_for_non_python_base(tmp_path):
	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.1.5']},
		latest_version={'poetry': '2.1.5'},
		base_variants=['slim'],
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	tags = {e['image_tag'] for e in matrix}
	assert tags == {'poetry2.1.5'}


def test_generate_build_matrix_multi_package_cartesian_product(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python', 'poetry'],
		{'python': ['3.14.6'], 'poetry': ['2.1.5', '2.0.0']},
		latest_version={'python': '3.14.6', 'poetry': '2.1.5'},
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	tags = {e['image_tag'] for e in matrix}
	assert tags == {
		'python3.14.6-poetry2.1.5',
		'python3.14.6-poetry2.0.0',
	}


def test_generate_build_matrix_unlabeled_package_drops_prefix(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python?', 'poetry'],
		{'python': ['3.14.6'], 'poetry': ['2.1.5']},
		latest_version={'python': '3.14.6', 'poetry': '2.1.5'},
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	tags = {e['image_tag'] for e in matrix}
	assert tags == {'3.14.6-poetry2.1.5'}


def test_generate_build_matrix_common_metadata_merged_into_entries(tmp_path):
	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.1.5']},
		latest_version={'poetry': '2.1.5'},
		common_metadata={'images_prefix': 'devbox-python'},
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	assert matrix[0]['images_prefix'] == 'devbox-python'


def test_generate_build_matrix_skips_published_tags(tmp_path):
	versions_path = make_versions_file(
		tmp_path,
		{'poetry': ['2.1.5', '2.0.0']},
		{'poetry': '2.1.5'},
	)
	published_tags_path = tmp_path / 'published_tags.yml'
	write_yaml(published_tags_path, {'published_tags': ['poetry2.1.5']})

	bm = BuildMatrix(
		packages=['poetry'],
		versions_path=versions_path,
		published_tags_path=str(published_tags_path),
		output_path=str(tmp_path / 'build_matrix.yml'),
	)
	matrix = bm.generate_build_matrix(skip_published_tags=True)
	tags = {e['image_tag'] for e in matrix}
	assert tags == {'poetry2.0.0'}


def test_generate_build_matrix_missing_published_tags_file_warns_and_continues(tmp_path, capsys):
	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.1.5']},
		latest_version={'poetry': '2.1.5'},
	)
	matrix = bm.generate_build_matrix(skip_published_tags=True)
	assert len(matrix) == 1
	assert 'Published tags file' in capsys.readouterr().err


# --- save_build_matrix_file ---


def test_save_build_matrix_file_overwrite(tmp_path):
	output_path = tmp_path / 'build_matrix.yml'
	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.1.5']},
		latest_version={'poetry': '2.1.5'},
		output_path=str(output_path),
	)
	bm.generate_build_matrix(skip_published_tags=False)
	bm.save_build_matrix_file(append=False)

	saved = yaml.safe_load(output_path.read_text())
	assert len(saved['build_matrix']) == 1
	assert 'last_updated' in saved


def test_save_build_matrix_file_append(tmp_path):
	output_path = tmp_path / 'build_matrix.yml'
	write_yaml(output_path, {'build_matrix': [{'image_tag': 'existing'}]})

	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.1.5']},
		latest_version={'poetry': '2.1.5'},
		output_path=str(output_path),
	)
	bm.generate_build_matrix(skip_published_tags=False)
	bm.save_build_matrix_file(append=True)

	saved = yaml.safe_load(output_path.read_text())
	tags = [e['image_tag'] for e in saved['build_matrix']]
	assert tags == ['existing', 'poetry2.1.5']


def test_save_build_matrix_file_overwrite_drops_existing_entries(tmp_path):
	output_path = tmp_path / 'build_matrix.yml'
	write_yaml(output_path, {'build_matrix': [{'image_tag': 'existing'}]})

	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.1.5']},
		latest_version={'poetry': '2.1.5'},
		output_path=str(output_path),
	)
	bm.generate_build_matrix(skip_published_tags=False)
	bm.save_build_matrix_file(append=False)

	saved = yaml.safe_load(output_path.read_text())
	tags = [e['image_tag'] for e in saved['build_matrix']]
	assert tags == ['poetry2.1.5']


# --- _check_version_constraint ---


@pytest.mark.parametrize(
	'version,constraint,expected',
	[
		# Less-than
		('3.9.25', '<3.10', True),
		('3.10.0', '<3.10', False),
		('3.11.0', '<3.10', False),
		# Greater-than-or-equal
		('2.0.0', '>=2.0', True),
		('2.3.4', '>=2.0', True),
		('1.8.5', '>=2.0', False),
		# Equal
		('3.9.25', '==3.9', True),
		('3.10.0', '==3.9', False),
		# Not-equal
		('3.9.25', '!=3.10', True),
		('3.10.0', '!=3.10', False),
		# Greater-than
		('3.11.0', '>3.10', True),
		('3.10.0', '>3.10', False),
		# Less-than-or-equal
		('3.10.0', '<=3.10', True),
		('3.11.0', '<=3.10', False),
	],
)
def test_check_version_constraint(version, constraint, expected):
	assert BuildMatrix._check_version_constraint(version, constraint) == expected


# --- _is_compatible ---

SKIP_COMBINATIONS_POETRY_PYTHON = [
	{
		'when': {'python': '<3.10'},
		'skip': {'poetry': '>=2.0'},
	}
]


def test_is_compatible_python39_poetry1_is_compatible(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python', 'poetry'],
		{'python': ['3.9.25'], 'poetry': ['1.8.5']},
		constraints={'skip_combinations': SKIP_COMBINATIONS_POETRY_PYTHON},
	)
	assert bm._is_compatible({'python': '3.9.25', 'poetry': '1.8.5'}) is True


def test_is_compatible_python39_poetry2_is_incompatible(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python', 'poetry'],
		{'python': ['3.9.25'], 'poetry': ['2.3.4']},
		constraints={'skip_combinations': SKIP_COMBINATIONS_POETRY_PYTHON},
	)
	assert bm._is_compatible({'python': '3.9.25', 'poetry': '2.3.4'}) is False


def test_is_compatible_python310_poetry2_is_compatible(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python', 'poetry'],
		{'python': ['3.10.0'], 'poetry': ['2.3.4']},
		constraints={'skip_combinations': SKIP_COMBINATIONS_POETRY_PYTHON},
	)
	assert bm._is_compatible({'python': '3.10.0', 'poetry': '2.3.4'}) is True


def test_is_compatible_no_constraints(tmp_path):
	bm = make_matrix(
		tmp_path,
		['python', 'poetry'],
		{'python': ['3.9.25'], 'poetry': ['2.3.4']},
	)
	assert bm._is_compatible({'python': '3.9.25', 'poetry': '2.3.4'}) is True


def test_is_compatible_missing_when_package_skips_rule(tmp_path):
	"""Rule doesn't apply when 'when' package is absent from the combination."""
	bm = make_matrix(
		tmp_path,
		['poetry'],
		{'poetry': ['2.3.4']},
		constraints={'skip_combinations': SKIP_COMBINATIONS_POETRY_PYTHON},
	)
	assert bm._is_compatible({'poetry': '2.3.4'}) is True


def test_is_compatible_missing_skip_package_doesnt_skip(tmp_path):
	"""Rule doesn't skip when 'skip' package is absent from the combination."""
	bm = make_matrix(
		tmp_path,
		['python'],
		{'python': ['3.9.25']},
		constraints={'skip_combinations': SKIP_COMBINATIONS_POETRY_PYTHON},
	)
	assert bm._is_compatible({'python': '3.9.25'}) is True


# --- generate_build_matrix with compatibility filtering ---


def test_generate_build_matrix_skips_incompatible_combinations(tmp_path):
	"""Python 3.9 + Poetry 2.x combinations are excluded when the rule is active."""
	bm = make_matrix(
		tmp_path,
		['python', 'poetry'],
		{
			'python': ['3.14.6', '3.9.25'],
			'poetry': ['2.3.4', '1.8.5'],
		},
		latest_version={'python': '3.14.6', 'poetry': '2.3.4'},
		constraints={'skip_combinations': SKIP_COMBINATIONS_POETRY_PYTHON},
	)
	matrix = bm.generate_build_matrix(skip_published_tags=False)
	tags = {e['image_tag'] for e in matrix}
	# python3.9.25-poetry2.3.4 must be absent; all other combinations are fine
	assert 'python3.9.25-poetry2.3.4' not in tags
	assert 'python3.9.25-poetry1.8.5' in tags
	assert 'python3.14.6-poetry2.3.4' in tags
	assert 'python3.14.6-poetry1.8.5' in tags
