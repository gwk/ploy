# © 2015 George King.
# Permission to use this file is granted in ploy/license.txt.

'''
rudimentary type system.
'''

import io as _io
import inspect as _inspect
import sys as _sys
import types as _types

from collections import defaultdict as _defaultdict, OrderedDict as _OrderedDict
from functools import wraps
from keyword import iskeyword as _iskeyword


fset = frozenset # abbreviation.

# capitalize builtin types names for stylistic consistency within annotations.
Bool = bool
Char = str
Flt = float
Int = int
Str = str
TextFile = _io.TextIOWrapper

check_collections_shallow = True
check_calls = True


def _replace_fwd(orig, final):
  'helper function for _fulfill implementations to replace Fwd types with final types.'
  if isinstance(orig, Fwd) and orig.name == final.name:
    return final
  return orig

_fwd_dependents = _defaultdict(set) # maps fwd declared names to types that depend on them.

def _update_dependencies(T, dependencies):
  # first register T as dependent on each dependency (struct fields or union variants).
  for D in dependencies:
    if isinstance(D, Fwd):
      s = _fwd_dependents[D.name]
      if s is None:
        raise TypeError('Fwd has already been fulfilled: {}'.format(D.name))
      s.add(T) # T depends on final of D, which has not yet been defined.
  # then fulfill all types that depend on T (possibly including itself, just registered).
  try:
    name = T.name
  except AttributeError:
    return # if T does not have a name then it cannot have a Fwd, so nobody depends on it.
  for D in _fwd_dependents[name]:
    D._fulfill(T)
  _fwd_dependents[name] = None # this Fwd has already been fulfilled; just use the final type.

def _type_name(T):
  if isinstance(T, Type):
    return str(T)
  else:
    return T.__name__


class Obj:
  'the "Any" type.'
  def __init__(self):
    raise TypeError('Obj cannot be insantiated.')

  @classmethod
  def is_a(cls, o): return True


class Type(object):
  'abstract base class for all type annotation types.'

  _memo = {}

  def __new__(cls, *args, **kw):
    'type annotation objects are memoized.'
    k = (cls, args)
    try:
      return cls._memo[k]
    except KeyError: pass
    o = object.__new__(cls)
    cls._memo[k] = o
    # assign name only if specified.
    try:
      o.name = kw['name']
    except KeyError:
      pass
    return o

  def __init__(self):
    raise TypeError('{} annotation type cannot be instantiated'.format(self.__class__.__name__))

  def __repr__(self):
    try:
      return self.name
    except AttributeError:
      pass
    return '{}({})'.format(self.__class__.__name__, ','.join(_type_name(e) for e in self.els))

  @classmethod
  def is_a(cls, o):
    '''
    note: this is the metatype test;
    subclasses of Type implement is_a as an instance method.
    '''
    return isinstance(o, (type, Type))


class Tuple(Type):
  'annotation type for struct-like tuples (as opposed to sequence-like tuples; see Array).'
  inst_type = tuple

  def __init__(self, *els):
    self.els = els

  def is_a(self, o):
    return (isinstance(o, self.inst_type)
      and len(o) == len(self.els) and all(is_a(*p) for p in zip(o, self.els)))

  def _fulfill(self, final):
    'replace any forward types.'
    self.els = tuple(_replace_fwd(e, final) for e in self.els)


class Collection(Type):
  'abstract base class for collection types (List, Set, etc).'
  def __init__(self, E):
    self.E = E
    self.els = (E,)

  def is_a(self, o):
    return (isinstance(o, self.inst_type)
      and (check_collections_shallow or all(is_a(e, self.E) for e in o))) # O(n).

  def _fulfill(self, final):
    'replace any forward types.'
    self.E = _replace_fwd(self.E, final)
    self.els = (self.E,)


class List(Collection):
  inst_type = list

class Set(Collection):
  inst_type = set

class FSet(Collection):
  inst_type = fset

class Array(Collection):
  'annotation type for sequence-like tuples (as opposed to struct-like tuples; see Tuple).'
  inst_type = tuple


class Dict(Collection):
  inst_type = dict
  
  def __init__(self, K, V):
    self.K = K
    self.V = V
    self.els = (K, V)

  def is_a(self, o):
    return (isinstance(o, self.inst_type)
      and (check_collections_shallow
        or all(is_a(k, self.K) and is_a(v, self.V) for k, v in o))) # O(n).

  def _fulfill(self, final):
    self.K = _replace_fwd(self.K, final)
    self.V = _replace_fwd(self.V, final)
    self.els = (self.K, self.V)


class Union(Type):
  def __init__(self, *variants, name=None):
    '''
    handle None as a special shorthand for type(None).
    Only supporting this here is sufficient because in practice only Union types contain None.
    '''
    t = tuple(type(None) if v is None else v for v in variants)
    s = frozenset(t)
    if len(t) != len(s):
      raise ValueError("Union type recieved multiple equivalent variants: {}".format(t))
    self.variants = s
    _update_dependencies(self, self.variants)

  @property
  def els(self):
    return sorted(self.variants, key=lambda t: str(t))

  def is_a(self, o):
    return any(is_a(o, V) for V in self.variants)

  def _fulfill(self, final):
    self.variants = frozenset(_replace_fwd(v, final) for v in self.variants)


class Opt(Union):
  def __init__(self, T):
    super().__init__(None, T)

  @property
  def T(self):
    '''
    this clumsy looking lookup avoids having to store T,
    which could become outdated after _fulfill.
    '''
    for v in self.variants:
      if v is not type(None):
        return v
    assert False

  def __str__(self):
    return 'Opt({})'.format(_type_name(self.T))


class Fwd:
  'a forward type declaration.'
  def __init__(self, name):
    self.name = name

  def __repr__(self):
    return 'Fwd({})'.format(self.name)

  def is_a(self, o):
    raise TypeError('is_a called on {}, which must be defined before use'.format(self))


def is_a(o:Obj, T:Type) -> Bool:
  # NOTE: if check_collections_shallow is False,
  # then this function is O(len(o)) for the collection types.
  try:
    m = T.is_a
  except AttributeError: pass
  else: return m(o)
  if not Type.is_a(T):
    raise TypeError('is_a received invalid type annotation: {}'.format(T))
  return isinstance(o, T)


_par_pos_kinds = (_inspect.Parameter.POSITIONAL_ONLY, _inspect.Parameter.POSITIONAL_OR_KEYWORD)

def check_fn(fn):
  'decorator for call-time type checking.'
  if not check_calls:
    return fn
  empty = _inspect.Parameter.empty
  sig = _inspect.signature(fn)
  ret_type = sig.return_annotation
  pars = sig.parameters
  if all(p.annotation is empty for p in pars.values()) and ret_type is empty:
    return fn

  if ret_type is empty:
    ret_type = type(None)
  name = '{}.{}'.format(fn.__module__, fn.__qualname__)
  try:
    named_pars_end = len(pars) # the index at which regular named positional arguments end.
    var_pos_par = None # the type of each arg in *args, if present.
    var_kw_par = None # the type of each arg in **kw, if present.
    kw_only_pars = {}
    for i, p in enumerate(pars.values()): # 'static' type check all defaults.
      if p.annotation is empty:
        raise TypeError("function {!r} parameter is missing annotation: {!r}".format(
          name, p))
      if not is_a(p.annotation, Type):
        raise TypeError("function {!r} parameter is not a Type: {!r}".format(name, p))
      if not (p.default is empty or is_a(p.default, p.annotation)):
        raise TypeError("function {!r} parameter default is nonconformant: {!r}".format(
          name, p))
      if p.kind not in _par_pos_kinds and i < named_pars_end:
        named_pars_end = i
      if p.kind == _inspect.Parameter.VAR_POSITIONAL:
        var_pos_par = p
      elif p.kind == _inspect.Parameter.KEYWORD_ONLY:
        kw_only_pars[p.name] = p
      elif p.kind == _inspect.Parameter.VAR_KEYWORD:
        var_kw_par = p
  except Exception:
    raise TypeError('check_fn failed: {!r}'.format(name))

  @wraps(fn)
  def dyn_type_check(*args, **kw):
    # check args.
    for i, (p, a) in enumerate(zip(pars.values(), args)):
      if i == named_pars_end: break
      if not (p.annotation is empty or is_a(a, p.annotation)):
        raise TypeError("function {!r} parameter {!r} received: {!r}".format(name, str(p), a))
    if var_pos_par:
      for i in range(named_pars_end, len(args)):
        if not is_a(args[i], var_pos_par.annotation):
          raise TypeError("function {!r} variadic parameter {!r} received: {!r}".format(
            name, str(var_pos_par), args[i]))
    for k, v in kw.items():
      try:
        p = kw_only_pars[k]
      except KeyError: pass
      else:
        if not is_a(v, p.annotation):
          raise TypeError("function {!r} keyword-only parameter {!r} received: {!r}".format(
            name, str(p), v))
        continue
      if var_kw_par and not is_a(v, var_kw_par.annotation):
        raise TypeError("function {!r} variadic keyword parameter {!r} received: {!r}".format(
          name, str(var_kw_par), v))

    res = fn(*args, **kw)

    # check return.
    if not is_a(res, ret_type):
      raise TypeError("function {!r} return type is {!r}; received: {!r}".format(
        name, str(ret_type), res))
    return res

  return dyn_type_check



def check_module():
  mod_globals = _sys._getframe(1).f_globals
  mod_name = mod_globals['__name__']
  for k, v in sorted(mod_globals.items()):
    if isinstance(v, _types.FunctionType):
      if v.__module__ != mod_name: continue
      mod_globals[k] = check_fn(v)


def def_struct(type_name, fields_str, verbose=False):
  '''
  Returns a new subclass of tuple with named fields.
  generate immutable tuple subclass types.
  like namedtuple, but:
    allows for type annotations and parameter defaults in the constructor.
    fields specifier must be a space-separated string;
      (commas are preserved for type annotations, which cannot contain spaces).
    field names are less limited.

  note: recursive and mutually recursive struct types can be declared using the Fwd class.
  a special syntactic prefix '^' is recognized and converted to Fwd;
  however this does not currently work when nested inside of Collection type declarations.
  '''

  _struct_fmt = '''\
from builtins import len, property, tuple, TypeError, ValueError
from builtins import getattr as _getattr, tuple as _tuple, type as _type
from operator import itemgetter
from collections import OrderedDict

_is_a = is_a

class {type_name}(tuple):
  "generated by def_struct."

  __slots__ = ()

  name = '{type_name}'
  _fields = None # OrderedDict, filled in after by def_struct after exec; replaces __new__.__annotations__.
  # NOTE: for some reason, when this class property was named 'fields',
  # it got returned by _getattr(_res, n) below; renamed it with leading underscore to avoid conflict (a hack).

  def __new__(_cls, {fields_str}):
    'Create new instance of {type_name}.'
    _res = _tuple.__new__(_cls, ({fields_tuple_str}))
    for n, F in _cls._fields.items():
      v = _getattr(_res, n)
      if not _is_a(v, F):
        raise TypeError('{type_name}.{{}} expects {{}}; received {{}}'.format(n, F, _type(v)))
    return _res

  @classmethod
  def from_seq(cls, iterable):
    'Make a new {type_name} object from an iterable.'
    res = tuple.__new__(cls, iterable)
    if len(res) != {num_fields}:
      raise TypeError('{type_name} expects {num_fields} argument{plural}, received {{}}'.format(len(res)))
    return res

  @classmethod
  def _fulfill(cls, final):
    for k, T in list(cls._fields.items()):
      if isinstance(T, Fwd) and T.name == final.name:
        cls._fields[k] = final

  def __repr__(self):
    'Return a formatted representation string.'
    return '{{}}({repr_fmt})'.format(self.__class__.__name__, *self)

  def __getnewargs__(self):
    'Return self as a plain tuple. Used by copy and pickle.'
    return tuple(self)

  def __getstate__(self):
    'Exclude the OrderedDict from pickling.'
    return None

  @property
  def __dict__(self):
    'A new OrderedDict mapping field names to their values'
    return OrderedDict(zip(self._fields, self))

  @property
  def _as_dict(self):
    'Return a new OrderedDict which maps field names to their values.'
    return self.__dict__

  def _update(self, **kw):
    'Return a new {type_name} object, replacing specified fields with new values.'
    res = self._from_seq(map(kw.pop, self._fields, self))
    if kw:
      raise ValueError('{type_name}.update() received invalid field names: {{}}'.format(kw))
    return res

  {field_defs}
'''

  _field_fmt = \
'''{name} = property(itemgetter({index}), doc="field {index}: {name}:{type}{eq_dflt}.")'''

  _reserved_names = { '_as_dict', '_cls', '_getattr', '_is_a', '_res', '_tuple',
    '_type', '_update' }

  def _ValErrF(fmt, *items):
    return ValueError(fmt.format(*items))

  def _field_triple_from_str(str):
    name, sep, rest = str.partition(':')
    if not rest:
      raise _ValErrF("field definition is missing type: {!r}", str)
    type_, sep, dflt = rest.partition('=')
    if sep and not dflt:
      raise _ValErrF("field definition is missing default: {!r}", str)
    if type_.startswith('^'): # forward declaration.
      type_ = "Fwd({!r})".format(type_[1:])
    return (name, type_, dflt or None) # default is optional.

  def _str_from_field_triple(triple):
    n, t, d = triple
    ds = '=' + d if d else ''
    return '{}:{}{}'.format(n, t, ds)

  def _validate_name(n):
    if type(n) != str:
      raise TypeError("struct/field name is not a str: {!r}".format(n))
    if not n.isidentifier():
      raise _ValErrF("struct/field name is not a valid identifier: {!r}", n)
    if _iskeyword(n):
      raise ValErrF("struct/field name cannot be a keyword: {!r}", n)
    if n.startswith('__'):
      raise ValErrF("struct/field name cannot begin with '__': {!r}", n)
    if n in _reserved_names:
      raise ValErrF("struct/field name is reserved: {!r}", n)


  _validate_name(type_name)
  field_strs = fields_str.split()
  num_fields = len(field_strs)
  field_triples = tuple(map(_field_triple_from_str, field_strs))
  fields_str = ', '.join(map(_str_from_field_triple, field_triples))
  field_names = tuple(n for n, t, d in field_triples)
  fields_tuple_str = ', '.join(field_names) + (',' if num_fields == 1 else '')
  field_name_set = set()
  for n in field_names:
    _validate_name(n)
    if n in field_name_set:
      raise _ValErrF("definition of {!r} contains duplicate field name: {!r}", type_name, n)
    field_name_set.add(n)

  repr_fmt = ', '.join('{}={{!r}}'.format(n) for n in field_names)

  field_defs = '\n  '.join(
    _field_fmt.format(index=i, name=n, type=t, eq_dflt=('=' + d if d else ''))
      for i, (n, t, d) in enumerate(field_triples))

  src = _struct_fmt.format(
    type_name=type_name,
    num_fields=num_fields,
    plural=('' if num_fields == 1 else 's'),
    fields_str=fields_str,
    fields_tuple_str=fields_tuple_str,
    repr_fmt=repr_fmt,
    field_defs=field_defs)

  src_numbered = '\n'.join('{:3}: {}'.format(i + 1, l) for i, l in enumerate(src.split('\n')))

  def _log_src():
    print('{}:'.format(type_name), '\n', src_numbered, sep='', file=_sys.stderr)

  if verbose:
    _log_src()

  # get the caller frame context.
  globals = _sys._getframe(1).f_globals
  locals = _sys._getframe(1).f_locals # identical to globals at module level.
  assert globals is locals # for now disallow inner def_struct; unknown ramifications.

  # execute the template string in a temporary namespace, but use caller's global environment.
  # this allows for the use of custom types in the type annotations,
  # as well as default values in the constructor.
  # it also means that the result's metadata is correct without further monkeying.
  try:
    exec(src, globals, locals)
  except:
    _log_src()
    raise

  result = locals[type_name]
  result._source = src

  # build the fields OrderedDict from the evaluated annotations.
  # use this to replace __annotations__, so that when fwd types get fulfilled,
  # the changes will show up correctly via both properties.
  annotations = result.__new__.__annotations__
  fields = _OrderedDict((n, annotations[n]) for n in field_names)
  result._fields = fields
  result.__new__.__annotations__ = fields
  _update_dependencies(result, fields.values())

  if verbose: print(type_name, '._fields: ', result._fields, sep='', file=_sys.stderr)


