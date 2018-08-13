// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class PolyRecord {
  let type: Type
  var typesToMorphs: [Type:Morph]

  init(type: Type, typesToMorphs: [Type:Morph]) {
    self.type = type
    self.typesToMorphs = typesToMorphs
  }

  func lazilyEmitMorph(globalCtx: GlobalCtx, sym: Sym, hostName: String, type: Type) -> String { // returns needsLazy.
    let morphHostName = "\(hostName)__\(type.globalIndex)"
    if let morph = typesToMorphs[type] {
      if let defCtx = morph.defCtx { // Non-nil defCtx implies that this morph is not yet emitted; do so now.
        morph.defCtx = nil
        let needsLazy = compileVal(defCtx: defCtx, hostName: morphHostName, val: morph.val, type: type)
        assert(!needsLazy)
      }
    } else { // synthesize morph.
      typesToMorphs[type] = Morph(defCtx: nil, val: .sym(sym)) // Fake morph with nil defCtx marks it as emitted.
      guard case .sig(let dom, _) = type.kind else { sym.fatal("unexpected synthesized morph type: \(type)") }
      guard case .any(let domMembers) = dom.kind else { sym.fatal("unexpected synthesized morph domain: \(dom)") }
      let em = Emitter(ctx: globalCtx)
      let tableName = "\(morphHostName)__$table" // bling: $table: dispatch table.
      em.str(0, "const \(tableName) = {")
      overDoms: for domMember in domMembers { // lazily emit all necessary concrete morphs for this synthesized morph.
        for morph in typesToMorphs.keys {
          if morph.sigDom == domMember {
            let memberHostName = lazilyEmitMorph(globalCtx: globalCtx, sym: sym, hostName: hostName, type: morph)
            em.str(2, "'\(domMember)': \(memberHostName),")
            continue overDoms
          }
        }
        sym.fatal("synthesizing morph \(type): no match for domain member: \(domMember); searched \(Array(typesToMorphs.keys))")
      }
      em.append("};") // close table.
      em.str(0, "const \(morphHostName) = $=>\(tableName)[$.$u]($.$m); // \(type)")
      em.flush()
    }
    return morphHostName
  }
}
