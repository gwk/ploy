// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class MainSpace: Space {

  let filePath: String

  init(filePath: String, rootSpace: Space, file: OutFile) {
    self.filePath = filePath
    super.init(pathNames: ["MAIN"], parent: rootSpace, file: file)
  }

  func getMainDef() -> Def {
    guard let def = defs["main"] else {
      fail("\(filePath): `main` is not defined in MAIN (toplevel namespace).")
    }
    return def
  }

  func compileMain() {
    let def = getMainDef()
    let record = getRecordInFrame(sym: def.sym)!
    let em = Emitter(file: self.file)
    compileSym(em, 0, scopeRecord: record, sym: def.sym, isTail: true)
    em.flush()
  }
}


func setupRootAndMain(mainPath: String, outFile: OutFile) -> (root: Space, main: MainSpace) {
  let root = Space(pathNames: ["ROOT"], parent: nil, file: outFile)
  root.bindings["ROOT"] = ScopeRecord(name: "ROOT", sym: nil, kind: .space(root)) // NOTE: reference cycle.
  // TODO: could fix the reference cycle by making a special case for "ROOT" just before lookup failure.
  for t in intrinsicTypes {
    let rec = ScopeRecord(name: t.description, sym: nil, kind: .type(t))
    root.bindings[t.description] = rec
  }
  let mainSpace = MainSpace(filePath: mainPath, rootSpace: root, file: outFile)
  root.bindings["MAIN"] = ScopeRecord(name: "MAIN", sym: nil, kind: .space(mainSpace))
  return (root, mainSpace)
}
