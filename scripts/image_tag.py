#!/usr/bin/env python3

import argparse
import json
import sys
from collections.abc import Sequence


class ImageTagGenerator:

	_TAG_LEVELS = ('patch', 'minor', 'major', 'global')

	_STANDARD_LEVELS = {
		'python': 'minor',
		'node': 'major',
	}

	def __init__(
		self,
		components: Sequence[
			tuple[str, str] | tuple[str, str, str] | tuple[str, str, str, str | None]
		],
		standard_levels: dict[str, str] | None = None,
	):
		"""
		Initialize the ImageTagGenerator with component versions and tag levels.
		:param components: List of tuples containing
			(component_name, version, tag_level, unlabeled_flag)
		:param standard_levels: Mapping of component name to the tag level it
			should be pinned to in the "standard" tag. Defaults to `_STANDARD_LEVELS`.
		"""
		self.standard_levels: dict[str, str] = (
			dict(self._STANDARD_LEVELS) if standard_levels is None else standard_levels
		)
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

	def _get_standard_tag(self) -> str | None:
		"""
		Build the "standard" tag: each known component is pinned to its
		standard tag level (e.g. python -> minor, node -> major), provided the
		component was requested at least as wide as that standard level. If any
		known component was requested narrower than its standard level, no
		standard tag can be built and None is returned. Components without a
		configured standard level use their own requested tag level.
		"""
		tag_pieces: list[str] = []

		for comp_name, comp_version, comp_tag_level, comp_unlabeled in self.components:
			target_level = self.standard_levels.get(comp_name)
			if target_level is not None:
				if self._TAG_LEVELS.index(comp_tag_level) < self._TAG_LEVELS.index(target_level):
					return None
				effective_level = target_level
			else:
				effective_level = comp_tag_level

			options = self._get_component_options(
				comp_name, comp_version, effective_level, comp_unlabeled
			)
			value = options[-1]
			if value:
				tag_pieces.append(value)

		return '-'.join(tag_pieces) if tag_pieces else None

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

		if not only_fully_qualified:
			standard_tag = self._get_standard_tag()
			if standard_tag and standard_tag not in tags:
				tags.append(standard_tag)

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
