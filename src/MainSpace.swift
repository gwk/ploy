// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


class MainSpace: Space {

  func getMainDef() -> Def {
    guard let def = defs["main"] else {
      fail("\(ctx.mainPath): `main` is not defined in MAIN (toplevel namespace).")
    }
    return def
  }

  func compileMain() {
    let def = getMainDef()
    _ = getRecordInFrame(sym: def.sym)!
    ctx.emitConversions()
  }
}


func setupRootAndMain(mainPath: String, outFile: OutFile) -> (root: Space, main: MainSpace) {
  let ctx = GlobalCtx(mainPath: mainPath, file: outFile)
  let root = Space(ctx, pathNames: ["ROOT"], parent: nil)
  root.bindings["ROOT"] = ScopeRecord(name: "ROOT", sym: nil, kind: .space(root)) // NOTE: reference cycle.
  // TODO: could fix the reference cycle by making a special case for "ROOT" just before lookup failure.
  for t in intrinsicTypes {
    let rec = ScopeRecord(name: t.description, sym: nil, kind: .type(t))
    root.bindings[t.description] = rec
  }
  let mainSpace = MainSpace(ctx, pathNames: ["MAIN"], parent: root)
  root.bindings["MAIN"] = ScopeRecord(name: "MAIN", sym: nil, kind: .space(mainSpace))
  return (root, mainSpace)
}
