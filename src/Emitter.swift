// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Foundation


class Emitter {
  let ctx: GlobalCtx
  var lines: [Line] = []

  deinit {
    assert(lines.isEmpty, "Emitter was not flushed.")
  }

  init(ctx: GlobalCtx) {
    self.ctx = ctx
  }

  func flush() {
    if lines.isEmpty { return }
    ctx.writeL()
    for line in lines {
      ctx.write(line: line)
    }
    lines.removeAll()
    ctx.writeL()
  }

  func str(_ indent: Int, _ text: String, syn: Syn? = nil, off: Int = 0, frameName: String = "") {
    let mapping: SrcMapping? = syn.and({
      (path: $0.source.name, line: $0.lineIdx, col: $0.colIdx, off: off, frameName: frameName)
    })
    lines.append((indent: indent, text: text, mapping: mapping))
  }

  func append(_ suffix: String) {
    var line = lines.last!
    line.text += suffix
    lines[lines.lastIndex!] = line
  }
}


func compileProgram(file: OutFile, mainPath: String, includePaths: [String], mainSpace: MainSpace, mapName: String) {
  // normal shebang line cannot pass necessary flags to node,
  // because shebang only respects one argument.
  let ctx = mainSpace.ctx
  #if true // simple thing to do is just use the standard node install path.
  ctx.writeL("#!/usr/local/bin/node --harmony-tailcalls")
  #else
  // alternative trick: launch as shell script, then immediately exec env with all arguments.
  // the hack relies on sh and node both interpreting the line;
  // node sees a string followed by a comment;
  // sh sees the no-op ':' command followed by the exec command.
  ctx.writeL("#!/bin/sh")
  ctx.writeL("':' //; exec /usr/bin/env node --harmony-tailcalls \"$0\" \"$@\"")
  #endif

  ctx.writeL("'use strict';")
  ctx.writeL("require('ploy-source-map').install();")
  ctx.writeL("(()=>{ // ploy root scope.")
  ctx.writeL("let $g = global;") // bling: $g: alias that cannot be shadowed.
  ctx.writeL("let $require = require;") // bling: $require: alias that cannot be shadowed.
  ctx.writeL("function $lazy_sentinal() { throw new Error('PLOY RUNTIME ERROR: lazy value init recursed.') };")

  for path in includePaths {
    let name = path.withoutPathDir
    ctx.writeL("// included: \(name).")
    let src = guarded { try String(contentsOfFile: path) }
    ctx.writeL(src)
    ctx.writeL("// end: \(name).")
    ctx.writeL()
  }

  let mainSyn = mainSpace.compileMain()
  ctx.emitConversions()

  ctx.writeL()
  let mainMapping = (path: mainSyn.source.name, lineIdx: mainSyn.lineIdx, colIdx: mainSyn.colIdx, off: 0, frameName: "<ploy>")
  ctx.writeL("MAIN__main__acc();", mainMapping)
  ctx.writeL("})(); // ploy root scope.")

  ctx.writeL("//# sourceMappingURL=\(mapName)")
}
