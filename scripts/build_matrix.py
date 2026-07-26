#!/usr/bin/env python3

import argparse
import itertools
import json
import os
import sys
from datetime import datetime, timezone
from typing import Any

import yaml

from scripts.image_tag import ImageTagGenerator


class BuildMatrix:

	def __init__(
		self,
		packages: list[str],
		base_variants: list[str] | set[str] | None = None,
		common_metadata: dict[str, Any] | None = None,
		versions_path: str = 'dist/versions.yml',
		published_tags_path: str = 'dist/published_tags.yml',
		skip_published_tags: bool = True,
		output_path: str = 'dist/build_matrix.yml',
	):
		self.base_variants: set[str] | None = set(base_variants) if base_variants else None
		self.common_metadata: dict[str, Any] = common_metadata or {}
		self.versions_path: str = versions_path
		self.published_tags_path: str = published_tags_path
		self.skip_published_tags: bool = skip_published_tags
		self.output_path: str = output_path

		self.packages: list[str] = []
		self.unlabeled_packages: set[str] = set()
		self.ghost_packages: set[str] = set()
		for raw_package in packages:
			package = raw_package.strip().lower()
			if not package:
				continue
			is_unlabeled = False
			is_ghost = False
			while True:
				if package.endswith('?'):
					package = package[:-1]
					is_unlabeled = True
				elif package.endswith('+'):
					package = package[:-1]
					is_ghost = True
				else:
					break
			if is_unlabeled:
				self.unlabeled_packages.add(package)
			if is_ghost:
				self.ghost_packages.add(package)
			self.packages.append(package)

		if not self.packages:
			raise ValueError('No packages specified for build matrix generation.')

		self.versions: dict[str, Any] = self._load_yaml(versions_path)

		self.build_matrix: list[dict[str, str]] = []

	def _load_yaml(self, path: str) -> Any:
		"""Load YAML configuration file."""
		try:
			with open(path) as f:
				return yaml.safe_load(f)
		except FileNotFoundError as err:
			raise FileNotFoundError(f'Error: {path} not found') from err

	def _get_version_tuple(self, version: str) -> tuple[int, int, int]:
		parts = version.split('.', 2)
		return (
			int(parts[0]),
			int(parts[1]) if len(parts) > 1 else 0,
			int(parts[2]) if len(parts) > 2 else 0,
		)

	def _get_component_tag_level(
		self, packages_version: dict[str, str], latest_versions: dict[str, str], package: str
	) -> str:
		package_version = packages_version.get(package)
		if package_version and latest_versions.get(package) == package_version:
			return 'global'
		return 'minor'

	def _get_component_unlabeled_flag(self, package: str) -> str | None:
		if package in self.unlabeled_packages:
			return 'always'
		if package in self.ghost_packages:
			return 'global'
		return None

	@staticmethod
	def _format_component(
		comp_name: str, comp_version: str, comp_tag_level: str, comp_unlabeled: str | None
	) -> str:
		unlabeled_flag = '?' if comp_unlabeled else ''
		return f'{comp_name}{unlabeled_flag}={comp_version}:{comp_tag_level}'

	def generate_build_matrix(
		self,
		skip_published_tags: bool = True,
	) -> list[dict[str, str]]:
		"""Generate build matrix from detected versions for specified packages."""
		print(f'Generating build matrix for packages: {", ".join(self.packages)}...')

		all_detected_versions = self.versions.get('detected_versions', {})
		all_latest_versions = self.versions.get('latest_version', {})
		all_base_variants = {
			'python': {'', 'slim', 'alpine'},
		}

		base_package = self.packages[0]
		other_packages = self.packages[1:]

		detected_versions = {}
		latest_versions = {}
		for package in self.packages:
			package_versions = all_detected_versions.get(package, [])
			if not package_versions:
				print(
					f"Error: No detected versions found for package '{package}'.", file=sys.stderr
				)
				sys.exit(1)
			detected_versions[package] = package_versions
			latest_versions[package] = all_latest_versions.get(package, package_versions[0])

		# base_variants = all_base_variants.get(base_package) or [None]
		base_variants = all_base_variants.get(base_package)
		selected_base_variants = (
			self.base_variants.intersection(base_variants)
			if self.base_variants and base_variants
			else [None]
		)

		if skip_published_tags:
			try:
				published_tags: set[str] = self._load_yaml(self.published_tags_path).get(
					'published_tags', set()
				)
				print(f'Detected {len(published_tags)} published tags.')
			except FileNotFoundError:
				print(
					f"Warning: Published tags file '{self.published_tags_path}' not found.",
					file=sys.stderr,
				)
				published_tags = set()
		else:
			published_tags = set()
			print('Skipped published tags check.')

		build_matrix = []

		for versions_combo in itertools.product(*detected_versions.values()):
			packages_version = dict(zip(self.packages, versions_combo, strict=True))

			for base_variant in selected_base_variants:
				image_tag_components: list[tuple[str, str, str, str | None]] = [
					(
						base_package,
						packages_version[base_package],
						self._get_component_tag_level(
							packages_version, latest_versions, base_package
						),
						self._get_component_unlabeled_flag(base_package),
					),
					*(
						[(f'{base_package}_variant', base_variant, 'patch', 'always')]
						if base_variant is not None
						else []
					),
					*[
						(
							other_package,
							packages_version[other_package],
							self._get_component_tag_level(
								packages_version, latest_versions, other_package
							),
							self._get_component_unlabeled_flag(other_package),
						)
						for other_package in other_packages
					],
				]
				image_tag_generator = ImageTagGenerator(
					components=[
						(comp_name, comp_version, 'patch', comp_unlabeled)
						for (comp_name, comp_version, _, comp_unlabeled) in image_tag_components
					]
				)
				image_tag_generator.generate_tags(only_fully_qualified=True)
				image_tag = (
					image_tag_generator.image_tags[0] if image_tag_generator.image_tags else None
				)

				if not image_tag:
					print(
						f'Warning: Failed to generate image tag for versions {packages_version}.',
						file=sys.stderr,
					)
					continue
				if image_tag in published_tags:
					continue  # Skip already published tags

				build_matrix.append(
					{
						**self.common_metadata,
						'image_tag': image_tag,
						'image_tag_components': ','.join(
							self._format_component(*comp) for comp in image_tag_components
						),
						'build_args': json.dumps(
							[
								f'{base_package.upper()}_VERSION={packages_version[base_package]}',
								*(
									[f'{base_package.upper()}_VARIANT={base_variant}']
									if base_variant is not None
									else []
								),
								*[
									f'{other_package.upper()}_VERSION={packages_version[other_package]}'
									for other_package in other_packages
								],
							]
						),
					}
				)

		print(f'Generated {len(build_matrix)} build matrix entries.')
		self.build_matrix = build_matrix
		return build_matrix

	def save_build_matrix_file(self, append: bool = False) -> None:
		"""Save build matrix to output file."""
		print(f'Saving build matrix to {self.output_path}...')

		# Load existing data to preserve past detected versions
		try:
			with open(self.output_path) as f:
				existing = yaml.safe_load(f) or {}
		except FileNotFoundError:
			existing = {}

		if append:
			build_matrix = existing.get('build_matrix', []) + self.build_matrix
		else:
			build_matrix = self.build_matrix

		data = {
			'last_updated': datetime.now(timezone.utc).isoformat() + 'Z',
			'build_matrix': build_matrix,
		}

		# Save to output file
		os.makedirs(os.path.dirname(self.output_path), exist_ok=True)
		with open(self.output_path, 'w') as f:
			yaml.dump(data, f, default_flow_style=False, sort_keys=False)

		print(f'Build matrix saved to {self.output_path}.')


def _parse_bool(value: str) -> bool:
	"""Parse string to boolean."""
	if isinstance(value, bool):
		return value
	return value.lower() in ('true', '1', 'yes', 'on')


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description='Generate build matrix from detected versions.',
	)
	parser.add_argument(
		'packages',
		nargs='+',
		help='Packages to include in build matrix. If empty, all are included.',
	)
	parser.add_argument(
		'--common-metadata',
		type=str,
		default='',
		help=(
			'Comma-separated list or JSON list of common metadata to include '
			'in build matrix entries.'
		),
	)
	parser.add_argument(
		'--base-variants',
		type=str,
		default='',
		help=(
			'Comma-separated list or JSON list of base variants to build '
			'(e.g. "", "slim", "alpine").'
		),
	)
	parser.add_argument(
		'--skip-published-tags',
		type=_parse_bool,
		default=True,
		help=(
			'Skip tags already published to the registry (true/false). '
			'Set to false to force rebuild/inclusion of existing tags.'
		),
	)
	parser.add_argument(
		'--append',
		action='store_true',
		default=False,
		help=(
			'Append to existing build matrix instead of overwriting. '
			'This will merge new entries with existing ones.'
		),
	)
	return parser.parse_args()


def main():

	args = parse_args()

	packages_input = None
	if args.packages and len(args.packages) == 1:
		packages_input = str(args.packages[0]).strip()
		try:
			packages_input = json.loads(packages_input)
		except json.JSONDecodeError:
			packages_input = packages_input.split(',')
	if not packages_input:
		packages_input = args.packages

	base_variants_input = None
	if args.base_variants:
		base_variants_input = str(args.base_variants).strip()
		try:
			base_variants_input = json.loads(base_variants_input)
		except json.JSONDecodeError:
			base_variants_input = base_variants_input.split(',')

	common_metadata_input = {}
	if args.common_metadata:
		common_metadata_input = str(args.common_metadata).strip()
		try:
			common_metadata_input = json.loads(common_metadata_input)
		except json.JSONDecodeError:
			common_metadata_input = dict(
				pair.split('=', 1) for pair in common_metadata_input.split(',') if '=' in pair
			)

	try:
		matrix_builder = BuildMatrix(
			packages=packages_input,
			common_metadata=common_metadata_input,
			base_variants=base_variants_input,
			skip_published_tags=args.skip_published_tags,
		)
	except ValueError as e:
		print(f'Error: {e}', file=sys.stderr)
		sys.exit(1)

	# Generate build matrix
	matrix_builder.generate_build_matrix()

	# Save build matrix file
	matrix_builder.save_build_matrix_file(
		append=args.append,
	)


if __name__ == '__main__':
	main()
