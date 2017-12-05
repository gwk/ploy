// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class PolyRecord {
  let sym: Sym
  let hostName: String
  let type: Type
  let typesToMorphs: [Type:Morph]

  init(sym: Sym, hostName: String, type: Type, typesToMorphs: [Type:Morph]) {
    self.sym = sym
    self.hostName = hostName
    self.type = type
    self.typesToMorphs = typesToMorphs
  }

  func lazilyEmitMorph(type: Type) -> String { // returns needsLazy.
    guard let morph = typesToMorphs[type] else { sym.fatal("poly is missing type: \(type)") }
    let morphHostName = "\(hostName)__\(morph.type.globalIndex)"
    if let defCtx = morph.defCtx {
      morph.defCtx = nil
      morph.needsLazy = compileVal(defCtx: defCtx, hostName: morphHostName, val: morph.val, type: morph.type)
    }
    return morph.needsLazy! ? "\(morphHostName)__acc()" : morphHostName
  }
}
