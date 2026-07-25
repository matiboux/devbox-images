import yaml
import pytest

from scripts.detect_versions import DetectVersions


def write_constraints(tmp_path, data):
    path = tmp_path / 'constraints.yml'
    path.write_text(yaml.dump(data, sort_keys=False))
    return str(path)


def make_detector(tmp_path, package_name, constraints=None, **kwargs):
    constraints_path = write_constraints(tmp_path, constraints or {})
    return DetectVersions(
        package_name=package_name,
        constraints_path=constraints_path,
        output_path=str(tmp_path / 'versions.yml'),
        **kwargs,
    )


# --- __init__ ---

def test_invalid_package_name_raises(tmp_path):
    with pytest.raises(ValueError):
        make_detector(tmp_path, 'not-a-real-package')


def test_package_name_normalized_lower_and_stripped(tmp_path):
    detector = make_detector(tmp_path, '  Python  ')
    assert detector.package_name == 'python'


def test_missing_constraints_file_warns_and_defaults_empty(tmp_path, capsys):
    detector = DetectVersions(
        package_name='python',
        constraints_path=str(tmp_path / 'missing.yml'),
        output_path=str(tmp_path / 'versions.yml'),
    )
    assert detector.constraints == {}
    assert 'not found' in capsys.readouterr().err


@pytest.mark.parametrize(
    'package,expected_scope',
    [
        ('python', 'minor'),
        ('poetry', 'minor'),
        ('uv', 'minor'),
        ('node', 'major'),
        ('nvm', 'minor'),
        ('yarn', 'major'),
        ('pnpm', 'major'),
        ('docker', 'major'),
    ],
)
def test_default_scope_per_package(tmp_path, package, expected_scope):
    detector = make_detector(tmp_path, package)
    assert detector.scope == expected_scope


def test_docker_detects_static_pseudo_version(tmp_path):
    detector = make_detector(tmp_path, 'docker')
    assert detector.detect_versions() == ['docker']
    assert detector.latest_version == 'docker'


def test_invalid_scope_raises(tmp_path):
    with pytest.raises(ValueError):
        make_detector(tmp_path, 'python', scope='bogus')


def test_explicit_scope_overrides_default(tmp_path):
    detector = make_detector(tmp_path, 'python', scope='patch')
    assert detector.scope == 'patch'


# --- load_past_detected_versions ---

def test_load_past_detected_versions_missing_file_returns_empty(tmp_path):
    detector = make_detector(tmp_path, 'python')
    assert detector.load_past_detected_versions() == {}


def test_load_past_detected_versions_reads_existing_file(tmp_path):
    detector = make_detector(tmp_path, 'python')
    output_path = tmp_path / 'versions.yml'
    output_path.write_text(
        yaml.dump({'detected_versions': {'python': ['3.14', '3.13']}})
    )
    detector.output_path = str(output_path)
    assert detector.load_past_detected_versions() == {'python': ['3.14', '3.13']}


# --- version helpers ---

@pytest.mark.parametrize(
    'version,expected',
    [
        ('3', (3, 0, 0)),
        ('3.14', (3, 14, 0)),
        ('3.14.6', (3, 14, 6)),
    ],
)
def test_get_version_tuple(tmp_path, version, expected):
    detector = make_detector(tmp_path, 'python')
    assert detector._get_version_tuple(version) == expected


@pytest.mark.parametrize(
    'value,expected',
    [
        (None, None),
        ('', None),
        ('3', (3,)),
        ('3.14', (3, 14)),
        ('3.14.6', (3, 14, 6)),
        ('3.14.6.99', (3, 14, 6)),
    ],
)
def test_get_version_filter_tuple(tmp_path, value, expected):
    detector = make_detector(tmp_path, 'python')
    assert detector._get_version_filter_tuple(value) == expected


def test_get_version_filter_tuple_invalid_returns_none(tmp_path, capsys):
    detector = make_detector(tmp_path, 'python')
    assert detector._get_version_filter_tuple('abc') is None
    assert 'Invalid version filter' in capsys.readouterr().err


@pytest.mark.parametrize(
    'version_tuple,filter_tuple,expected',
    [
        ((3, 14, 6), None, True),
        ((3, 14, 6), (3,), True),
        ((3, 14, 6), (3, 14), True),
        ((3, 14, 6), (3, 14, 6), True),
        ((3, 14, 6), (3, 13), False),
        ((3, 14, 6), (4,), False),
    ],
)
def test_version_matches_filter(tmp_path, version_tuple, filter_tuple, expected):
    detector = make_detector(tmp_path, 'python')
    assert detector._version_matches_filter(version_tuple, filter_tuple) == expected


def test_get_version_key_patch_scope(tmp_path):
    detector = make_detector(tmp_path, 'python', scope='patch')
    assert detector._get_version_key((3, 14, 6)) == '3.14.6'


def test_get_version_key_major_scope(tmp_path):
    detector = make_detector(tmp_path, 'node', scope='major')
    assert detector._get_version_key((26, 1, 0)) == '26'


def test_get_version_key_minor_scope(tmp_path):
    detector = make_detector(tmp_path, 'python', scope='minor')
    assert detector._get_version_key((3, 14, 6)) == '3.14'


def test_sort_versions_descending(tmp_path):
    detector = make_detector(tmp_path, 'python')
    grouped = {'3.13': '3.13.9', '3.14': '3.14.6', '3.9': '3.9.1'}
    assert detector._sort_versions(grouped) == ['3.14.6', '3.13.9', '3.9.1']


# --- detect_versions dispatch ---

def test_detect_versions_sets_latest_when_no_filter(tmp_path, monkeypatch):
    detector = make_detector(tmp_path, 'python')
    monkeypatch.setitem(detector._detectors, 'python', lambda past: ['3.14.6', '3.13.9'])
    result = detector.detect_versions()
    assert result == ['3.14.6', '3.13.9']
    assert detector.latest_version == '3.14.6'


def test_detect_versions_no_latest_when_filter_set(tmp_path, monkeypatch):
    detector = make_detector(tmp_path, 'python', version_filter='3.14')
    monkeypatch.setitem(detector._detectors, 'python', lambda past: ['3.14.6'])
    detector.detect_versions()
    assert detector.latest_version is None


def test_detect_versions_empty_result_no_latest(tmp_path, monkeypatch):
    detector = make_detector(tmp_path, 'python')
    monkeypatch.setitem(detector._detectors, 'python', lambda past: [])
    detector.detect_versions()
    assert detector.latest_version is None


# --- _detect_docker_image (python) ---

def single_page(results):
    return lambda url: {'results': results}


def test_detect_docker_image_filters_by_min_version_and_groups_by_scope(tmp_path, monkeypatch):
    detector = make_detector(
        tmp_path,
        'python',
        constraints={'python': {'min_version': '3.10', 'docker_image': 'library/python'}},
        scope='minor',
    )
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        single_page(
            [
                {'name': '3.14.6'},
                {'name': '3.14.5'},
                {'name': '3.9.20'},  # below min_version, dropped
                {'name': 'not-a-version'},  # non-numeric, dropped
            ]
        ),
    )
    result = detector._detect_docker_image()
    assert result == ['3.14.6']


def test_detect_docker_image_extra_versions_bypass_min_version(tmp_path, monkeypatch):
    detector = make_detector(
        tmp_path,
        'python',
        constraints={
            'python': {
                'min_version': '3.10',
                'extra_versions': ['2.7'],
                'docker_image': 'library/python',
            }
        },
    )
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        single_page([{'name': '2.7.18'}, {'name': '3.14.6'}]),
    )
    result = detector._detect_docker_image()
    assert set(result) == {'2.7.18', '3.14.6'}


def test_detect_docker_image_skip_versions(tmp_path, monkeypatch):
    detector = make_detector(
        tmp_path,
        'python',
        constraints={
            'python': {
                'min_version': '3.10',
                'skip_versions': ['3.11'],
                'docker_image': 'library/python',
            }
        },
    )
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        single_page([{'name': '3.11.9'}, {'name': '3.12.7'}]),
    )
    result = detector._detect_docker_image()
    assert result == ['3.12.7']


def test_detect_docker_image_version_filter_narrows_results(tmp_path, monkeypatch):
    detector = make_detector(
        tmp_path,
        'python',
        constraints={'python': {'min_version': '3.10', 'docker_image': 'library/python'}},
        version_filter='3.12',
    )
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        single_page([{'name': '3.12.7'}, {'name': '3.14.6'}]),
    )
    result = detector._detect_docker_image()
    assert result == ['3.12.7']


def test_detect_docker_image_paginates_until_no_next(tmp_path, monkeypatch):
    detector = make_detector(
        tmp_path,
        'python',
        constraints={'python': {'min_version': '3.10', 'docker_image': 'library/python'}},
    )
    pages = {
        'page1': {
            'results': [{'name': '3.14.6'}],
            'next': 'page2',
        },
        'page2': {
            'results': [{'name': '3.13.9'}],
            # no 'next' key: loop must stop here even though this page has matches
        },
    }
    monkeypatch.setattr(detector, '_fetch_json', lambda url: pages.get(url, pages['page1']))
    result = detector._detect_docker_image()
    assert set(result) == {'3.14.6', '3.13.9'}


def test_detect_docker_image_incomplete_constraints_stops_after_first(tmp_path, monkeypatch, capsys):
    detector = make_detector(tmp_path, 'python', constraints={})
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        lambda url: {'results': [{'name': '3.14.6'}, {'name': '3.13.9'}]},
    )
    result = detector._detect_docker_image()
    assert result == ['3.14.6']
    assert 'not found in constraints' in capsys.readouterr().err


def test_detect_docker_image_missing_min_version_warns(tmp_path, monkeypatch, capsys):
    detector = make_detector(
        tmp_path, 'python', constraints={'python': {'docker_image': 'library/python'}}
    )
    monkeypatch.setattr(detector, '_fetch_json', lambda url: {'results': [{'name': '3.14.6'}]})
    detector._detect_docker_image()
    assert "'min_version' not specified" in capsys.readouterr().err


def test_detect_docker_image_no_docker_image_for_unknown_package_returns_past(tmp_path, monkeypatch, capsys):
    # Has to be a package other than "python": _detect_docker_image falls back
    # to a hardcoded `known_repos` map when constraints don't set a
    # docker_image, and python is in that map, so it'd hit the network instead
    # of exercising the "no known docker_image" branch. Poetry isn't wired up
    # to this detector normally, but it's a fine stand-in here.
    detector = make_detector(tmp_path, 'poetry', constraints={'poetry': {'min_version': '1.0'}})
    result = detector._detect_docker_image(past_detected_versions=['3.13.9'])
    assert result == ['3.13.9']
    assert "No 'docker_image' specified" in capsys.readouterr().err


def test_detect_docker_image_fetch_failure_falls_back_to_past(tmp_path, monkeypatch, capsys):
    detector = make_detector(
        tmp_path,
        'python',
        constraints={'python': {'min_version': '3.10', 'docker_image': 'library/python'}},
    )
    monkeypatch.setattr(detector, '_fetch_json', lambda url: {})
    result = detector._detect_docker_image(past_detected_versions=['3.14.6', '3.9.1'])
    # 3.9.1 is below min_version, dropped even in the fallback path
    assert result == ['3.14.6']
    assert 'Could not fetch package versions' in capsys.readouterr().err


# --- _detect_node_versions ---

def test_detect_node_versions_filters_and_groups(tmp_path, monkeypatch):
    detector = make_detector(
        tmp_path,
        'node',
        constraints={'node': {'min_version': '20'}},
        scope='major',
    )
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        lambda url: [
            {'version': 'v22.10.0'},
            {'version': 'v22.9.0'},
            {'version': 'v18.20.4'},  # below min_version
        ],
    )
    result = detector._detect_node_versions()
    assert result == ['22.10.0']


def test_detect_node_versions_non_list_response_returns_empty_no_fallback(tmp_path, monkeypatch, capsys):
    detector = make_detector(tmp_path, 'node', constraints={'node': {'min_version': '20'}})
    monkeypatch.setattr(detector, '_fetch_json', lambda url: {})
    result = detector._detect_node_versions(past_detected_versions=['22.10.0'])
    # unlike the docker/github detectors, a failed fetch here returns [] rather
    # than falling back to past_detected_versions
    assert result == []
    assert 'Could not fetch versions from Node.js API' in capsys.readouterr().err


# --- _detect_github_repo ---

def test_detect_github_repo_known_repo_uv_no_prefix(tmp_path, monkeypatch):
    detector = make_detector(tmp_path, 'uv', constraints={'uv': {'min_version': '0.8'}})
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        lambda url: [{'ref': 'refs/tags/0.8.13'}, {'ref': 'refs/tags/0.7.0'}],
    )
    result = detector._detect_github_repo()
    assert result == ['0.8.13']


def test_detect_github_repo_known_repo_nvm_v_prefix(tmp_path, monkeypatch):
    detector = make_detector(tmp_path, 'nvm', constraints={'nvm': {'min_version': '0.40'}})
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        lambda url: [{'ref': 'refs/tags/v0.40.3'}, {'ref': 'refs/tags/v0.39.0'}],
    )
    result = detector._detect_github_repo()
    assert result == ['0.40.3']


def test_detect_github_repo_custom_github_repo_from_constraints(tmp_path, monkeypatch):
    detector = make_detector(
        tmp_path,
        'poetry',
        constraints={
            'poetry': {
                'min_version': '2.1',
                'github_repo': 'python-poetry/poetry',
                'version_prefix': '',
            }
        },
    )
    monkeypatch.setattr(
        detector,
        '_fetch_json',
        lambda url: [{'ref': 'refs/tags/2.1.5'}],
    )
    result = detector._detect_github_repo()
    assert result == ['2.1.5']


def test_detect_github_repo_invalid_response_falls_back_to_past(tmp_path, monkeypatch, capsys):
    # A transient fetch failure falls back to past_detected_versions, but still
    # applies min_version/skip_versions/extra_versions filtering and sorting,
    # same as the successful-but-empty-response fallback path.
    detector = make_detector(tmp_path, 'uv', constraints={'uv': {'min_version': '0.8'}})
    monkeypatch.setattr(detector, '_fetch_json', lambda url: {})
    result = detector._detect_github_repo(past_detected_versions=['0.8.13', '0.5.0'])
    assert result == ['0.8.13']
    assert 'Could not fetch tags from GitHub' in capsys.readouterr().err


# --- _detect_pip_package (not wired into detect_versions() yet, but still part of the API) ---

def test_detect_pip_package_parses_pip_index_output(tmp_path, monkeypatch):
    detector = make_detector(tmp_path, 'uv', constraints={'uv': {'min_version': '0.8'}})

    class FakeResult:
        returncode = 0
        stdout = 'Available versions: 0.8.13, 0.8.0, 0.7.0\n'

    import subprocess as subprocess_module

    monkeypatch.setattr(subprocess_module, 'run', lambda *a, **kw: FakeResult())
    result = detector._detect_pip_package()
    assert result == ['0.8.13']


def test_detect_pip_package_handles_run_exception(tmp_path, monkeypatch, capsys):
    detector = make_detector(tmp_path, 'uv', constraints={'uv': {'min_version': '0.8'}})

    import subprocess as subprocess_module

    def raise_err(*a, **kw):
        raise OSError('boom')

    monkeypatch.setattr(subprocess_module, 'run', raise_err)
    result = detector._detect_pip_package(past_detected_versions=['0.8.13'])
    assert result == ['0.8.13']
    assert 'pip index versions failed' in capsys.readouterr().err


# --- save_versions_file ---

def test_save_versions_file_writes_and_merges_existing(tmp_path, monkeypatch):
    detector = make_detector(tmp_path, 'python')
    output_path = tmp_path / 'versions.yml'
    output_path.write_text(
        yaml.dump(
            {
                'detected_versions': {'node': ['22.10.0']},
                'latest_version': {'node': '22.10.0'},
            }
        )
    )
    detector.output_path = str(output_path)
    detector.detected_versions = ['3.14.6']
    detector.latest_version = '3.14.6'

    detector.save_versions_file()

    saved = yaml.safe_load(output_path.read_text())
    assert saved['detected_versions'] == {'node': ['22.10.0'], 'python': ['3.14.6']}
    assert saved['latest_version'] == {'node': '22.10.0', 'python': '3.14.6'}
    assert 'last_updated' in saved


def test_save_versions_file_no_latest_version_key_added_when_none(tmp_path):
    detector = make_detector(tmp_path, 'python', version_filter='3.14')
    detector.detected_versions = ['3.14.6']
    detector.latest_version = None

    detector.save_versions_file()

    saved = yaml.safe_load((tmp_path / 'versions.yml').read_text())
    assert saved['latest_version'] == {}
