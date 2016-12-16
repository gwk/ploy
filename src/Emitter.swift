// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class Emitter {
  let file: OutFile
  var lines: [String] = []

  deinit {
    assert(lines.isEmpty, "Emitter was not flushed.")
  }

  init(file: OutFile) {
    self.file = file
  }

  func flush() {
    if !lines.isEmpty {
      file.write("\n")
      for line in lines {
        file.write(line)
        file.write("\n")
      }
      lines.removeAll()
    }
  }

  func str(_ depth: Int, _ string: String) {
    lines.append(String(indent: depth) + string)
  }

  func append(_ string: String) {
    lines[lines.lastIndex!] = lines.last! + string
  }
}


func compileProgram(file: OutFile, includePaths: [String], mainSpace: MainSpace) {
  // normal shebang line cannot pass necessary flags to node,
  // because shebang only respects one argument.
  #if true // simple thing to do is just use the standard node install path.
  file.writeL("#!/usr/local/bin/node --harmony-tailcalls")
  #else
  // alternative trick: launch as shell script, then immediately exec env with all arguments.
  // the hack relies on sh and node both interpreting the line;
  // node sees a string followed by a comment;
  // sh sees the no-op ':' command followed by the exec command.
  file.writeL("#!/bin/sh")
  file.writeL("':' //; exec /usr/bin/env node --harmony-tailcalls \"$0\" \"$@\"\n")
  #endif

  file.writeL("\"use strict\";\n")
  file.writeL("(()=>{ // ploy scope.\n")
  file.writeL("function _lazy_sentinal() { throw 'INTERNAL RUNTIME ERROR: lazy value init recursed.' };")

  for path in includePaths {
    let name = path.withoutPathDir
    file.writeL("// included: \(name).")
    let src = guarded { try String(contentsOfFile: path) }
    file.writeL(src)
    file.writeL("// end: \(name).\n")
  }

  mainSpace.compileMain()
  file.writeL("})();")
}
