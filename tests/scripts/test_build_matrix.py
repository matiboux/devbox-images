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


def make_matrix(tmp_path, packages, detected_versions, latest_version=None, **kwargs):
    versions_path = make_versions_file(tmp_path, detected_versions, latest_version)
    kwargs.setdefault('published_tags_path', str(tmp_path / 'published_tags.yml'))
    kwargs.setdefault('output_path', str(tmp_path / 'build_matrix.yml'))
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
    # The strip loop peels one trailing flag char at a time and checks '?' before
    # '+', so combining both on one package ("python?+") ends up adding "python?"
    # to ghost_packages instead of the clean name. Probably a bug, but nothing
    # combines both flags today, so this just pins the current behavior.
    bm = make_matrix(tmp_path, ['python?+'], {'python': ['3.14.6']})
    assert bm.packages == ['python']
    assert bm.unlabeled_packages == {'python'}
    assert bm.ghost_packages == {'python?'}


# --- _get_component_tag_level / _get_component_unlabeled_flag ---

def test_component_tag_level_patch_when_matches_latest(tmp_path):
    bm = make_matrix(tmp_path, ['python'], {'python': ['3.14.6']})
    assert bm._get_component_tag_level({'python': '3.14.6'}, {'python': '3.14.6'}, 'python') == 'patch'


def test_component_tag_level_minor_when_not_latest(tmp_path):
    bm = make_matrix(tmp_path, ['python'], {'python': ['3.14.6', '3.13.9']})
    assert bm._get_component_tag_level({'python': '3.13.9'}, {'python': '3.14.6'}, 'python') == 'minor'


def test_component_tag_level_minor_when_package_missing(tmp_path):
    bm = make_matrix(tmp_path, ['python'], {'python': ['3.14.6']})
    assert bm._get_component_tag_level({}, {'python': '3.14.6'}, 'python') == 'minor'


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


def test_generate_build_matrix_python_base_variants(tmp_path):
    # Pins current behavior: the variant component isn't marked 'unlabeled', so
    # it renders as "python_variantslim" rather than the bare "slim" suffix
    # README.md documents.
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
        'python3.14.6-python_variantslim',
        'python3.14.6-python_variantalpine',
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
    assert tags == {'python3.14.6-python_variantslim'}


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
