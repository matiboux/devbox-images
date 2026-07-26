#!/usr/bin/env python3

import argparse
import json
import sys
from collections.abc import Sequence
from itertools import product


class ImageTagGenerator:

	def __init__(
		self,
		components: Sequence[
			tuple[str, str] | tuple[str, str, str] | tuple[str, str, str, str | None]
		],
	):
		"""
		Initialize the ImageTagGenerator with component versions and tag levels.
		:param components: List of tuples containing
			(component_name, version, tag_level, unlabeled_flag)
		"""
		self.components: list[tuple[str, str, str, str | None]] = [
			(
				(
					comp[0],
					comp[1],
					self._validate_tag_level(comp[2]),
					comp[3] if len(comp) >= 4 else None,
				)
				if len(comp) >= 3
				else (comp[0], comp[1], 'patch', None)
			)
			for comp in components
		]

		self.image_tags: list[str] = []

	@staticmethod
	def _validate_tag_level(level: str) -> str:
		if level in ('global', 'major', 'minor', 'patch'):
			return level
		return 'patch'

	def _get_component_options(
		self, package: str, version: str, level: str, unlabeled: str | None = None
	) -> list[str]:

		if not version:
			return ['']

		version_parts = version.split('.')
		major = version_parts[0]
		minor = f'{version_parts[0]}.{version_parts[1]}' if len(version_parts) >= 2 else version

		version_prefix = '' if unlabeled == 'always' else package

		raw_options: list[str] = []
		if level == 'global':
			global_tag = '' if unlabeled in ('always', 'global') else package
			raw_options = [
				f'{version_prefix}{version}',
				f'{version_prefix}{minor}',
				f'{version_prefix}{major}',
				global_tag,
			]
		elif level == 'major':
			raw_options = [
				f'{version_prefix}{version}',
				f'{version_prefix}{minor}',
				f'{version_prefix}{major}',
			]
		elif level == 'minor':
			raw_options = [f'{version_prefix}{version}', f'{version_prefix}{minor}']
		else:  # 'patch'
			raw_options = [f'{version_prefix}{version}']

		# De-duplicate while preserving order
		options: list[str] = []
		for item in raw_options:
			if item not in options:
				options.append(item)

		return options

	def generate_tags(
		self,
		only_fully_qualified: bool = False,
	) -> list[str]:

		component_options_list = []
		tag_level_override = 'patch' if only_fully_qualified else None
		for comp_name, comp_version, comp_tag_level, comp_unlabeled in self.components:
			options = self._get_component_options(
				comp_name, comp_version, tag_level_override or comp_tag_level, comp_unlabeled
			)
			component_options_list.append(options)

		tags: list[str] = []
		for component_values in product(*component_options_list):
			tag_pieces: list[str] = []

			for i in range(len(self.components)):
				if component_values[i]:
					tag_pieces.append(component_values[i])

			image_tag = '-'.join(tag_pieces) if tag_pieces else 'latest'

			tags.append(image_tag)

		self.image_tags = tags
		return tags

	def print_tags(
		self,
		compact_output: bool = False,
	) -> None:
		"""
		Print the generated image tags to stdout.
		:param compact_output: If True, output tags as comma-separated values on a single line
		"""
		if compact_output:
			print(','.join(self.image_tags))
		else:
			for tag in self.image_tags:
				print(tag)


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description='Generate Docker image tags for the devbox image.',
	)
	parser.add_argument(
		'components',
		nargs='+',
		help=(
			'List of components in the format: component_name[?]=version[:tag_level]. '
			'Example: python?=3.14.6:global =slim poetry=20.5.1:minor'
		),
	)
	parser.add_argument(
		'-c',
		'--compact',
		action='store_true',
		help='Output tags as comma-separated values on a single line',
	)
	return parser.parse_args()


def main():

	args = parse_args()

	components_input = None
	if args.components and len(args.components) == 1:
		components_input = str(args.components[0]).strip()
		try:
			components_input = json.loads(components_input)
		except json.JSONDecodeError:
			components_input = components_input.split(',')
	if not components_input:
		components_input = args.components

	components: list[tuple[str, str, str, str | None]] = []
	for comp in components_input:
		if '=' not in comp:
			print(
				f'Invalid component format: {comp}. '
				'Expected format: component_name=version[:tag_level]',
				file=sys.stderr,
			)
			sys.exit(1)
		comp_name, version_tag = comp.split('=', 1)
		comp_unlabeled: str | None = None
		while True:
			if comp_name.endswith('?'):
				comp_name = comp_name[:-1]
				comp_unlabeled = 'always'
			elif comp_name.endswith('+'):
				comp_name = comp_name[:-1]
				comp_unlabeled = 'global'
			else:
				break
		if ':' in version_tag:
			version, tag_level = version_tag.split(':', 1)
			components.append((comp_name, version, tag_level, comp_unlabeled))
		else:
			components.append((comp_name, version_tag, 'patch', comp_unlabeled))

	generator = ImageTagGenerator(
		components=components,
	)

	generator.generate_tags()

	generator.print_tags(
		compact_output=args.compact,
	)


if __name__ == '__main__':
	main()
