#!/usr/bin/env python3

from datetime import datetime, timezone
from typing import Any, Dict, List, Tuple
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

import yaml


class BuildMatrix:

    def __init__(
        self,
        versions_path: str = 'dist/versions.yml',
        constraints_path: str = 'constraints.yml',
        output_path: str = 'dist/build-matrix.yml',
    ):
        self.versions: Dict[str, Any] = self._load_yaml(versions_path)
        self.constraints: Dict[str, Any] = self._load_yaml(constraints_path)
        self.output_path: str = output_path
        self.build_matrix: List[Dict[str, str]] = []

    def _load_yaml(self, path: str) -> dict:
        """Load YAML configuration file."""
        try:
            with open(path, 'r') as f:
                return yaml.safe_load(f) or {}
        except FileNotFoundError:
            print(f"Error: {path} not found", file=sys.stderr)
            sys.exit(1)

    def _fetch_json(self, url: str, timeout: int = 10) -> dict:
        """Fetch JSON from URL with error handling."""
        try:
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'python-devbox/1.0')
            with urllib.request.urlopen(req, timeout=timeout) as response:
                return json.loads(response.read().decode())
        except (urllib.error.URLError, json.JSONDecodeError) as e:
            print(f"Warning: Failed to fetch {url}: {e}", file=sys.stderr)
            return {}

    def _get_version_tuple(self, version: str) -> Tuple[int, int, int]:
        parts = version.split('.', 2)
        return (
            int(parts[0]),
            int(parts[1]) if len(parts) > 1 else 0,
            int(parts[2]) if len(parts) > 2 else 0
        )

    def _fetch_published_tags(self) -> List[str]:
        """Fetch published tags from Docker Hub."""

        published_tags: List[str] = []

        min_python_version = self.constraints['python']['min_version']
        min_poetry_version = self.constraints['poetry']['min_version']
        min_uv_version = self.constraints['uv']['min_version']
        min_python_version_tuple = self._get_version_tuple(min_python_version)
        min_poetry_version_tuple = self._get_version_tuple(min_poetry_version)
        min_uv_version_tuple = self._get_version_tuple(min_uv_version)

        url: str | None = 'https://hub.docker.com/v2/namespaces/matiboux/repositories/python-devbox/tags?page_size=100'
        for _ in range(100):  # Limit to 100 pages to avoid infinite loop
            if not url:
                break
            data = self._fetch_json(url)
            if not data:
                print(
                    'Warning: Could not fetch published tags from Docker Hub',
                    file=sys.stderr,
                )
            if 'results' not in data:
                break
            for tag in data['results']:
                try:
                    tag_name = tag.get('name', '')
                    if not tag_name or 'slim' in tag_name:
                        continue
                    tag_match = re.match(r'^(?P<python>\d+\.\d+\.\d+)(?:-poetry(?P<poetry>\d+\.\d+\.\d+))?(?:-uv(?P<uv>\d+\.\d+\.\d+))?$', tag_name)
                    if not tag_match:
                        continue
                    python_version = tag_match.group('python')
                    poetry_version = tag_match.group('poetry')
                    uv_version = tag_match.group('uv')
                    if python_version:
                        python_version_tuple = self._get_version_tuple(python_version)
                        if python_version_tuple < min_python_version_tuple:
                            continue
                    if poetry_version:
                        poetry_version_tuple = self._get_version_tuple(poetry_version)
                        if poetry_version_tuple < min_poetry_version_tuple:
                            continue
                    if uv_version:
                        uv_version_tuple = self._get_version_tuple(uv_version)
                        if uv_version_tuple < min_uv_version_tuple:
                            continue
                    published_tags.append(tag_name)
                except (ValueError, IndexError):
                    pass
            url = data.get('next')

        return published_tags

    def generate_build_matrix(
        self,
        skip_published_tags: bool = True,
    ) -> List[dict[str, str]]:
        """Generate GitHub Actions matrix from detected versions."""
        print('Generating build matrix...')

        detected_versions = self.versions.get('detected_versions', {})
        python_versions = detected_versions.get('python', [])
        poetry_versions = detected_versions.get('poetry', [])
        uv_versions = detected_versions.get('uv', [])

        if not python_versions:
            print('Error: No Python versions detected', file=sys.stderr)
            sys.exit(1)

        if skip_published_tags:
            published_tags = set(self._fetch_published_tags())
            print(f"Detected {len(published_tags)} published tags.")
        else:
            published_tags = set()
            print('Skipped published tags check.')

        latest_python_version = python_versions[0] if python_versions else None
        latest_poetry_version = poetry_versions[0] if poetry_versions else None
        latest_uv_version = uv_versions[0] if uv_versions else None

        build_matrix = []
        for python_version in python_versions:
            python_tag_level = 'global' if python_version == latest_python_version else 'minor'
            if f"{python_version}" not in published_tags:
                build_matrix.append({
                    'image_tag': f"{python_version}",
                    'python_version': python_version,
                    'python_image_variant': '',
                    'python_tag_level': python_tag_level,
                })
                build_matrix.append({
                    'image_tag': f"{python_version}-slim",
                    'python_version': python_version,
                    'python_image_variant': 'slim',
                    'python_tag_level': python_tag_level,
                })
                build_matrix.append({
                    'image_tag': f"{python_version}-alpine",
                    'python_version': python_version,
                    'python_image_variant': 'alpine',
                    'python_tag_level': python_tag_level,
                })
            for poetry_version in poetry_versions:
                poetry_tag_level = 'global' if poetry_version == latest_poetry_version else 'minor'
                if f"{python_version}-poetry{poetry_version}" not in published_tags:
                    build_matrix.append({
                        'image_tag': f"{python_version}-poetry{poetry_version}",
                        'python_version': python_version,
                        'python_image_variant': '',
                        'poetry_version': poetry_version,
                        'python_tag_level': python_tag_level,
                        'poetry_tag_level': poetry_tag_level,
                    })
                    build_matrix.append({
                        'image_tag': f"{python_version}-slim-poetry{poetry_version}",
                        'python_version': python_version,
                        'python_image_variant': 'slim',
                        'poetry_version': poetry_version,
                        'python_tag_level': python_tag_level,
                        'poetry_tag_level': poetry_tag_level,
                    })
                    build_matrix.append({
                        'image_tag': f"{python_version}-alpine-poetry{poetry_version}",
                        'python_version': python_version,
                        'python_image_variant': 'alpine',
                        'poetry_version': poetry_version,
                        'python_tag_level': python_tag_level,
                        'poetry_tag_level': poetry_tag_level,
                    })
            for uv_version in uv_versions:
                uv_tag_level = 'global' if uv_version == latest_uv_version else 'minor'
                if f"{python_version}-uv{uv_version}" not in published_tags:
                    build_matrix.append({
                        'image_tag': f"{python_version}-uv{uv_version}",
                        'python_version': python_version,
                        'python_image_variant': '',
                        'uv_version': uv_version,
                        'python_tag_level': python_tag_level,
                        'uv_tag_level': uv_tag_level,
                    })
                    build_matrix.append({
                        'image_tag': f"{python_version}-slim-uv{uv_version}",
                        'python_version': python_version,
                        'python_image_variant': 'slim',
                        'uv_version': uv_version,
                        'python_tag_level': python_tag_level,
                        'uv_tag_level': uv_tag_level,
                    })
                    build_matrix.append({
                        'image_tag': f"{python_version}-alpine-uv{uv_version}",
                        'python_version': python_version,
                        'python_image_variant': 'alpine',
                        'uv_version': uv_version,
                        'python_tag_level': python_tag_level,
                        'uv_tag_level': uv_tag_level,
                    })

        print(f"Generated {len(build_matrix)} build matrix entries.")
        self.build_matrix = build_matrix
        return build_matrix

    def save_build_matrix_file(self):
        """Save build matrix to output file."""
        print(f"Saving build matrix to {self.output_path}...")

        # Load existing data to preserve past detected versions
        try:
            with open(self.output_path, 'r') as f:
                existing = yaml.safe_load(f) or {}
        except FileNotFoundError:
            existing = {}

        build_matrix = self.build_matrix or existing.get('build_matrix', [])

        data = {
            'last_updated': datetime.now(timezone.utc).isoformat() + 'Z',
            'build_matrix': build_matrix,
        }

        # Save to output file
        os.makedirs(os.path.dirname(self.output_path), exist_ok=True)
        with open(self.output_path, 'w') as f:
            yaml.dump(data, f, default_flow_style=False, sort_keys=False)

        print(f"Build matrix saved to {self.output_path}.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Generate build matrix from detected versions.',
    )
    parser.add_argument(
        '--skip-published-tags',
        action='store_true',
        default=True,
        help=(
            'Skip tags already published to the registry (true/false). '
            'Set to false to force rebuild/inclusion of existing tags.'
        ),
    )
    return parser.parse_args()


def main():

    args = parse_args()

    matrix_builder = BuildMatrix()

    # Generate build matrix
    matrix_builder.generate_build_matrix(
        skip_published_tags=args.skip_published_tags
    )

    # Save build matrix file
    matrix_builder.save_build_matrix_file()


if __name__ == "__main__":
    main()
