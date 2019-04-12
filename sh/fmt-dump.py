#!/usr/bin/env python3

import re
from dataclasses import dataclass
from typing import DefaultDict, Dict, List, NamedTuple, Tuple, Union

from pithy.ansi import *
from pithy.io import *
from pithy.sequence import iter_pairs_of_el_is_last
from pithy.loader import load
from pithy.iterable import set_from


class Loc(NamedTuple):
  path:str
  line:int
  col:int

  def __repr__(self) -> str: return f'{self.path}:{self.line+1}:{self.col+1}'


class Note(NamedTuple):
  loc:Loc
  msg:str


@dataclass
class Side:
  chainDesc:str
  loc:Loc
  type:str
  role:str

  @classmethod
  def from_json(cls, loc:str, **kwargs:str) -> 'Side':
    return cls(loc=parse_loc(loc), **kwargs)

  def __str__(self) -> str:
    color = role_colors[self.role]
    return f'{self.chainDesc}{self.role}: {color}{self.type}{RST}'


@dataclass
class Prop:
  loc:Loc
  accType:str
  accesseeType:str

  @classmethod
  def from_json(cls, loc:str, **kwargs:str) -> 'Prop':
    return cls(loc=parse_loc(loc), **kwargs)

  def notes(self, index:str) -> Iterator[Note]:
    yield Note(loc=self.loc, msg=f'#{index} acc:{self.accType} accessee:{self.accesseeType}')


@dataclass
class Rel:
  act:Side
  exp:Side
  desc:str

  def notes(self, index:int) -> Iterator[Note]:
    yield Note(loc=self.act.loc, msg=f'#{index} {self.desc} : {self.act}')
    yield Note(loc=self.exp.loc, msg=f'#{index} {self.desc} : {self.exp}')

  def __str__(self) -> str:
    loc_suffix = ''
    if self.act.loc != self.exp.loc:
      loc_suffix = f' @ {self.exp.loc.line+1}:{self.exp.loc.col+1}'
    return f'{self.desc} : {self.act} <~ {self.exp}{loc_suffix}'


Constraint = Union[Prop, Rel]


@dataclass
class TypeCtx:
  constraints:List[Constraint]
  freeParents:List[int]
  freeUnifications:List[str]
  freeNevers:List[int]

  @property
  def locs(self) -> Iterator[Loc]:
    for c in self.constraints:
      yield from c.locs


hooks = [
  TypeCtx,
  Prop,
  Rel,
  Side,
]


def main() -> None:
  _, dump_path = argv

  for defCtx in load(dump_path, hooks=hooks):
    render_def(defCtx)


def render_def(defCtx:Dict) -> None:

  def_path = defCtx['path']
  outL('\n\n', BG_D, 'Def: ', def_path, FILL)

  typeCtx = defCtx['typeCtx']

  constraints = typeCtx.constraints
  notes_set = set_from(c.notes(i) for i, c in enumerate(constraints))
  locs = set(n.loc for n in notes_set)
  line_indices = set(loc.line for loc in locs)

  # Collate notes by location parts.
  notes_tree:DefaultDict[str,DefaultDict[int,DefaultDict[int,List[Note]]]] = (
    DefaultDict(lambda: DefaultDict(lambda: DefaultDict(list))))

  for n in notes_set:
    l = n.loc
    notes_tree[l.path][l.line][l.col].append(n)

  for path, lines in sorted(notes_tree.items()):
    outL(path, ':', min(lines)+1)
    src_lines = list(open(path))
    for line, cols in sorted(lines.items()):
      src_line = '' if line < 0 else src_lines[line]
      outL(sgr(BG, gray26(3)), f'{line+1: 4d}| ', src_line.rstrip(), FILL)
      col_str = ''.join(('│' if col in cols else ' ') for col in range(len(src_line)))
      for col, col_notes in sorted(cols.items(), reverse=True):
        col_prefix = col_str[:col]
        for n, is_last in iter_pairs_of_el_is_last(sorted(col_notes)):
          outL('      ', col_prefix, '└' if is_last else '├', ' ', n.msg)

  nevers = set(typeCtx.freeNevers)
  outL('\nUnifications:')
  for i, t in enumerate(typeCtx.freeUnifications):
    never = f' (Never)' if i in nevers else ''
    if t is None and not never: continue
    num = f'#{i}'
    outL(f'  {num:>3}: ', t, never)


def parse_loc(loc_str:str) -> Loc:
  m = loc_re.fullmatch(loc_str)
  assert m, loc_str
  return Loc(m[1], int(m[2])-1, int(m[3])-1)

loc_re = re.compile(r'''(?x)
([^:]+):(\d+):(\d+)
''')


role_colors  = {
  'actual' : TXT_G,
  'argument' : TXT_Y,
  'expected' : TXT_C,
  'polyfunction' : TXT_M,
  'domain' : TXT_R,
  'return' : TXT_B,
}


if __name__ == '__main__': main()
