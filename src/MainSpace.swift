// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

import Foundation


class MainSpace: Space {

  func getMainDef() -> Def {
    guard let def = defs["main"] else {
      fail(label: "\(ctx.mainPath): error", "`main` is not defined in MAIN (toplevel namespace).")
    }
    return def
  }

  func compileMain() -> Syn {
    let def = getMainDef()
    _ = getRecordInFrame(sym: def.sym)!
    return def.sym.syn
  }
}
