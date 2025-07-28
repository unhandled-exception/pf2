#!/usr/bin/env python3

"""
Строить список классов Парсера в формате Маркдаун.
Первым параметром можно передать имя паки от которой ищем *.p-файлы иначе ищем от текущей
"""

import glob
import os
import re
import sys
from dataclasses import (
    dataclass,
)

p3_class_re = re.compile(
    r"""
        ^@CLASS.*\n(.+?)\n
        (?:^\#.*$|^\s*$)*
        (?:
            (?:[^@]*?@OPTIONS.*\n(?:(?:locals|partial"dynamic|static)\s*\n)+?)
            |
            (?:[^@]*?@USE.*\n(?:(?:\S)+\s*\n)+?)
        )*
        (?:^\#.*$|^\s*$)*
        (?:[^@]*?@BASE.*\n(.+?)\n)?
    """,
    flags=re.MULTILINE | re.VERBOSE,
)


@dataclass
class p3Class:
    path: str
    name: str
    base: str


def fetch_classes_from_file(source_path):
    result = []
    with open(source_path) as f:
        source = f.read()

    matches = p3_class_re.findall(source)
    for m in matches:
        result.append(p3Class(source_path, m[0], m[1]))

    return result


def find_classes(root_path, pattern="**/*.p"):
    result = []

    files = glob.glob(pattern, root_dir=root_path, recursive=True)
    files.sort()

    for fp in files:
        result.extend(fetch_classes_from_file(os.path.join(root_path, fp)))

    return result


def print_classes(root_path, classes):
    p = None
    for c in classes:
        if p != c.path:
            if p is not None:
                print()
            print(f"### [{c.path}]({c.path})")
        p = c.path

        base = f" <- {c.base}" if c.base != "" else ""
        print(f"* {c.name}{base}")


def main():
    root_path = "./"
    if len(sys.argv) > 1:
        root_path = sys.argv[1]

    classes = find_classes(root_path)
    print_classes(root_path, classes)


if __name__ == "__main__":
    main()
