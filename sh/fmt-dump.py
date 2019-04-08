#!/usr/bin/env python3

from pithy.loader import load
from pithy.io import *
from typing import *



def main() -> None:
  _, path = argv
  for obj in load(path):
    outD(obj)


if __name__ == '__main__': main()
