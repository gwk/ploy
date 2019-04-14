// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

import Foundation


class MainSpace: Space {
  let mainPath: Path

  init(_ ctx: GlobalCtx, mainPath: Path, parent: Space?) {
    self.mainPath = mainPath
    super.init(ctx, pathNames: ["MAIN"], parent: parent)
  }

  func getMainDef() -> Def {
    guard let def = defs["main"] else {
      fail(label: "\(mainPath): error", "`main` is not defined in MAIN (toplevel namespace).")
    }
    return def
  }

  func compileMain() -> Syn {
    let def = getMainDef()
    _ = getRecordInFrame(sym: def.sym)!
    return def.sym.syn
  }
}
