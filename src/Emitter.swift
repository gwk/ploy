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
      (pathString: $0.source.name, line: $0.lineIdx, col: $0.colIdx, off: off, frameName: frameName)
    })
    lines.append((indent: indent, text: text, mapping: mapping))
  }

  func append(_ suffix: String) {
    var line = lines.last!
    line.text += suffix
    lines[lines.lastIndex!] = line
  }
}


func compileProgram(mainPath: Path, includePaths: [Path], mainSpace: MainSpace, mapPath: Path) {
  let ctx = mainSpace.ctx
  ctx.writeL("#!/usr/bin/env node")

  ctx.writeL("'use strict';")
  ctx.writeL("require('ploy-source-map').install();")
  ctx.writeL("(()=>{ // ploy root scope.")
  ctx.writeL("const $g = global;") // bling: $g: alias that cannot be shadowed.
  ctx.writeL("const $require = require;") // bling: $require: alias that cannot be shadowed.
  ctx.writeL("const $lazy_sentinel = ()=>{ throw new Error('PLOY RUNTIME ERROR: lazy value init recursed.') };")

  for path in includePaths {
    let name = path.name
    ctx.writeL("// included: \(name).")
    let src = guarded { try File(path: path).readText() }
    ctx.writeL(src)
    ctx.writeL("// end: \(name).")
    ctx.writeL()
  }

  let mainSyn = mainSpace.compileMain()

  ctx.writeL()
  let mainMapping = (pathString: mainSyn.source.name, lineIdx: mainSyn.lineIdx, colIdx: mainSyn.colIdx, off: 0, frameName: "<ploy>")
  ctx.writeL("MAIN__main__acc();", mainMapping)
  ctx.writeL("})(); // ploy root scope.")

  ctx.writeL("//# sourceMappingURL=\(mapPath.expandUser)")
}
