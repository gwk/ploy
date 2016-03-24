#!/usr/bin/env python3
# Copyright 2015 George King.
# Permission to use this file is granted in ploy/license.txt.


import argparse
import ast
import os
import re
import shlex
import signal
import string as _string
import subprocess
import sys

from common.all import *


bar_width = 64
results_dir = '_build'

arg_parser = argparse.ArgumentParser(description='test harness for ploy.')
arg_parser.add_argument('-compiler', help='compiler command string')
arg_parser.add_argument('-timeout', type=int, help='subprocess timeout')
arg_parser.add_argument('-parse', action='store_true', help='parse test cases and exit'),
arg_parser.add_argument('-fast',  action='store_true', help='exit on first error'),
arg_parser.add_argument('-dbg', action='store_true', help='debug mode: print extra info; propagate exceptions; implies -fast)'),
arg_parser.add_argument('paths', nargs='*', help='test paths and/or directories to search')

args = arg_parser.parse_args()

dbg = args.dbg

if dbg:
  fail_fast = True
  logL("DEBUG")
else:
  fail_fast = args.fast


def lex(string):
  return shlex.split(string)

def quote(string):
  return shlex.quote(string)


def jsq(words):
  'join lists with spaces, quoting elements.'
  return quote(words) if isinstance(words, str) else ' '.join(quote(w) for w in words)

compiler_dflt = lex(args.compiler) if args.compiler else None

# file checks.

def compare_equal(exp, val):
  return exp == val

def compare_contain(exp, val):
  return val.find(exp) != -1

def compare_match(exp, val):
  return re.fullmatch(exp, val)

def compare_ignore(exp, val):
  return True


file_checks = {
  'equal'   : compare_equal,
  'contain' : compare_contain,
  'match'   : compare_match,
  'ignore'  : compare_ignore,
}

case_defaults = {
  'args'            : [], # arguments to the process being tested.
  'cmd'             : None, # optional command to launch test process.
  'code'            : 0, # expected exit code.
  'compile-code'    : 0, # expected compiler exit code.
  'compile-env'     : None, # compiler environment.
  'compile-err'     : '', # cmpiler std err expectation.
  'compile-files'   : {}, # compiler output file expectations.
  'compile-out'     : '', # compiler std out expectation.
  'compile-timeout' : 4,
  'compiler'        : compiler_dflt,
  'env'             : None,
  'err'             : '', # std err expectation.
  'files'           : {}, # process output file expectations.
  # files is a dict mapping file path to either an expectation string or (file-check-mode, expectation).
  'ignore'          : False, # ignore this test case.
  'in'              : None, # std in text.
  'libs'            : [], # list of library files.
  'main'            : None, # main file; defaults to file in test directory matching test name.
  'out'             : '', # std out expectation.
  'timeout'         : 4,
}

case_non_cmd_keys = { # keys that only make since in the absence of a custom cmd value.
  'compile-code',
  'compile-env',
  'compile-err',
  'compile-out',
  'compile-files',
  'compile-timeout',
  'libs',
  'main',
}

def run_cmd(cmd, timeout, exp_code, cwd, in_path, out_path, err_path, env):
  'run a subprocess; return True if process completed and exit code matched expectation.'

  # print verbose command info formatted as shell commands for manual repro.
  if dbg:
    logSL('cmd:', *(cmd + ['<{} # 1>{} 2>{}'.format(in_path, out_path, err_path)]))
    logSL('cwd:', cwd)
    if env:
      logSL('env:', *['{}={};'.format(*p) for p in env.items()])
  
  # open outputs, create subprocess.
  with open(in_path, 'r') as i, open(out_path, 'w') as o, open(err_path, 'w') as e:
    proc = subprocess.Popen(cmd, cwd=cwd, stdin=i, stdout=o, stderr=e, env=env)
    # timeout alarm handler.
    # since signal handlers carry reentrancy concerns, do not do any IO within the handler.
    timed_out = False
    def alarm_handler(signum, current_stack_frame):
      nonlocal timed_out
      timed_out = True
      proc.kill()

    signal.signal(signal.SIGALRM, alarm_handler) # set handler.
    signal.alarm(timeout) # set alarm.
    code = proc.wait() # wait for process to complete; change to communicate() for stdin support.
    signal.alarm(0) # disable alarm.
    
    if timed_out:
      outFL('process timed out ({} sec) and was killed', timeout)
      return False
    if code != exp_code:
      outFL('process returned bad code: {}; expected {}', code, exp_code)
      return False
    return True


def check_file_exp(path, mode, exp):
  'return True if file at path meets expectation.'
  if dbg: logFL('check_file_exp: path: {}; mode: {}; exp: {}', path, mode, repr(exp))
  try:
    with open(path) as f:
      val = f.read()
  except Exception as e:
    outSL('error reading test output file:', path)
    outSL('exception:', e) 
    outSL('-' * bar_width)
    return False
  if file_checks[mode](exp, val):
    return True
  outFL('output file {} does not {} expectation:', repr(path), mode)
  for line in exp.split('\n'):
    outL('\x1B[0;34m', line, '\x1B[0m') # blue text.
  if mode == 'equal': # show a diff.
    exp_path = path + '-expected'
    write_to_path(exp_path, exp)
    args = [exp_path, path]
    diff_cmd = 'git diff --histogram --no-index --no-prefix --no-renames --exit-code --color'.split() + args
    outSL(*diff_cmd)
    code = runC(diff_cmd, exp=None)
    return code == 0
  else:
    outSL('cat', path)
    with open(path) as f:
      for line in f:
        l = line.rstrip('\n')
        outL('\x1B[0;41m', l, '\x1B[0m') # red background.
        if not line.endswith('\n'):
          outL('(missing final newline)')
  outSL('-' * bar_width)
  return False


def check_cmd(cmd, timeout, exp_code, exp_triples, cwd, in_path, out_path, err_path, env):
  'run a command and check against file expectations; return True if all expectations matched.'
  code_ok = run_cmd(cmd, timeout, exp_code, cwd, in_path, out_path, err_path, env)
  # use a list comprehension to force evaluation of all triples; avoids break on first failure.
  files_ok = all([check_file_exp(*t) for t in exp_triples])
  return code_ok and files_ok


def run_case(case_path, case):
  'execute a test case.'
  outSL('executing:', case_path)
  # because we recreate the dir structure in the test results dir, parent dirs are forbidden.
  if case_path.find('..') != -1: raiseS("case path cannot contain '..':", case_path)
  src_dir, file_name = split_dir(case_path)
  case_name = split_ext(file_name)[0]
  exe_rel = '../' + case_name
  exe_path = path_join(results_dir, src_dir, case_name) # compiled exe path.
  test_dir = path_join(results_dir, src_dir, case_name + '-test') # test output directory.
  prof_cwd_path = 'default.profraw' # llvm name is fixed; always outputs to cwd.
  prof_path = exe_path + '.profraw'

  # remove old files.
  remove_file_if_exists(prof_cwd_path)
  remove_file_if_exists(exe_path)
  remove_file_if_exists(prof_path)
  # set up directory.
  if path_exists(test_dir):
    remove_dir_contents(test_dir)
  else:
    make_dirs(test_dir)

  if dbg: logLL(*('  {}: {}'.format(k, repr(v)) for k, v in sorted(case.items())))

  def checked_code(key):
    code = case[key]
    if not isinstance(code, int):
      raiseF('case {} {!r} has bad type: {!r}', key, code, type(code))
    return code

  code = checked_code('code')
  compile_code = checked_code('compile-code')

  def checked_timeout(key):
    timeout = case[key]
    if not (isinstance(timeout, int) and timeout > 0):
      raiseF('case {} {!r} has bad type: {}', key, timeout, type(timeout))
    return timeout

  timeout = checked_timeout('timeout')
  compile_timeout = checked_timeout('compile-timeout')

  compiler = case['compiler']

  test_env_vars = {    
    'SRC_DIR' : src_dir,
    'COMPILER' : jsq(compiler or 'NO-COMPILER'),
  }
  if dbg:
    logLSSL('test env vars:', *('{}: {!r}'.format(*kv) for kv in sorted(test_env_vars.items())))

  def expand(string):
    'test environment variable substitution; uses string template $ syntax.'
    t = _string.Template(string)
    return t.substitute(**test_env_vars)

  def expand_poly(val):
    'expand either a string or a list; polymorphic for ease of calling below.'
    if not val:
      return val
    if isinstance(val, str):
      return lex(expand(val))
    return [expand(str(v)) for v in val]

  env, cmd, args, rel_libs, rel_main = \
  (expand_poly(case[k]) for k in ('env', 'cmd', 'args', 'libs', 'main'))
  
  def make_exp_triples(out_key, err_key, files_key):
    'create exp_triples of (key, mode, expectation).'
    exps = { out_key : case[out_key], err_key : case[err_key] }
    for k in exps:
      if k in case[files_key]: raiseS('std file expectation shadowed by explicit file:', k)
    set_defaults(exps, case[files_key])
    exp_triples = []
    for k, v in sorted(exps.items()):
      path = path_join(test_dir, k + '.txt')
      mode, exp = ('equal', v) if isinstance(v, str) else v
      if mode in ('equal', 'contain'): # do not expand 'match' regexes; gets too confusing.
        exp = expand(exp)
      exp_triples.append((path, mode, exp))
    if dbg: logLSSL('file exp triples:', *exp_triples)
    return exp_triples

  if cmd:
    for k in non_cmd_keys:
      if case[k] is not None: raiseS('case specifies cmd, as well as irrelevant property:', k)

  elif compiler:
    if rel_main is None: # find default main source.
      all_files = os.listdir(src_dir)
      def is_src(n):
        base, ext = split_ext(n)
        return base == case_name and ext not in ('.test', '.h')
      dflt_mains = list(filter(is_src, all_files))
      if len(dflt_mains) != 1: raiseF('test case name matches multiple source files: {}', dflt_mains)
      rel_main = dflt_mains[0]
      if dbg: logSL('default main:', rel_main)
    libs = [path_join(src_dir, l) for l in rel_libs]
    compile_cmd = compiler + libs + ['-main', path_join(src_dir, rel_main), '-o', exe_path]
    ok = check_cmd(
      compile_cmd,
      compile_timeout,
      compile_code,
      exp_triples=make_exp_triples('compile-out', 'compile-err', 'compile-files'),
      cwd=None,
      in_path='/dev/null',
      out_path=path_join(test_dir, 'compile-out.txt'),
      err_path=path_join(test_dir, 'compile-err.txt'),
      env=env
    )
    if path_exists(prof_cwd_path):
      move_file(prof_cwd_path, prof_path)
    if not ok or compile_code != 0:
      return ok
    cmd = [exe_rel]
    
  else:
    raiseS('no cmd or compiler specified.')
  
  if case['in']:
    in_string = case['in']
    in_path = path_join(test_dir, 'in')
    write_to_path(in_path, in_string)
  else:
    in_path = '/dev/null'
  if dbg: logSL('input path:', in_path)

  # run test.
  ok = check_cmd(
    cmd + args,
    timeout,
    code,
    exp_triples=make_exp_triples('out', 'err', 'files'),
    cwd=test_dir,
    in_path=in_path,
    out_path=path_join(test_dir, 'out.txt'),
    err_path=path_join(test_dir, 'err.txt'),
    env=env,
  )
  return ok

  
def read_case(test_path):
  'read the test file.'
  with open(test_path) as f:
    s = f.read()
  if not s or s.isspace():
    case = {}
  else:
    case = ast.literal_eval(s)
    req_type(case, dict)
  for k in case:
    if k not in case_defaults:
      logSL('WARNING: bad test case key:', k)
  set_defaults(case, case_defaults)
  return case


# global counts.

test_count    = 0 # all tests.
skip_count    = 0 # tests that failed to read case.
ignore_count  = 0 # tests that specified ignore.
fail_count    = 0 # tests that ran but failed.


def try_case(path):
  global test_count, skip_count, ignore_count, fail_count
  test_count += 1
  try:
    case = read_case(path)
  except Exception as e:
    logFL('ERROR: could not read test case: {};\nexception: {}', path, e)
    skip_count += 1
    if dbg:
      raise
    else:
      return
  if case.get('ignore'):
    logSL('ignoring: ', path)
    ignore_count += 1
    return
  try:
    ok = run_case(path, case)
  except Exception as e:
    logFL('ERROR: could not run test case: {};\nexception: {}', path, e)
    if dbg: raise
    else:
      ok = False
  if not ok:
    fail_count += 1
    outL('=' * bar_width + '\n')
    if fail_fast:
      logFL('exiting fast.')
      sys.exit(1)


# parse and run tests.
for path in walk_all_files(*args.paths, exts=('.test',)):
  try_case(path)
  if dbg: logL()

out('\n' + '#' * bar_width + '\nRESULTS: ')
if not any([ignore_count, skip_count, fail_count]):
  outFL('PASSED {} test{}', test_count, ('' if test_count == 1 else 's'))
  code = 0
else:
  outFL('{} tests; IGNORED {}; SKIPPED {}; FAILED {}', test_count, ignore_count, skip_count, fail_count)
  code = 1

sys.exit(code)

