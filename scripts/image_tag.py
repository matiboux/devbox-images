#!/usr/bin/env python3

import argparse
import json
import sys
from collections.abc import Sequence


class ImageTagGenerator:

	_TAG_LEVELS = ('patch', 'minor', 'major', 'global')

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

		if only_fully_qualified:
			# Generate only the most specific tag, ignoring components tag levels.
			widest_scope = 0  # 'patch' tag level index
		else:
			widest_scope = max(
				(
					self._TAG_LEVELS.index(comp_tag_level)
					for *_, comp_tag_level, _ in self.components
				),
				default=0,
			)

		component_options_list = []
		for comp_name, comp_version, comp_tag_level, comp_unlabeled in self.components:
			effective_tag_level = 'patch' if only_fully_qualified else comp_tag_level
			options = self._get_component_options(
				comp_name, comp_version, effective_tag_level, comp_unlabeled
			)
			component_options_list.append(options)

		tags: list[str] = []
		for step in range(widest_scope + 1):
			tag_pieces: list[str] = []

			for options in component_options_list:
				value = options[min(step, len(options) - 1)]
				if value:
					tag_pieces.append(value)

			image_tag = '-'.join(tag_pieces) if tag_pieces else 'latest'

			if not tags or tags[-1] != image_tag:
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
