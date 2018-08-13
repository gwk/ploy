// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class PolyRecord {

  enum Morph {
    case compiled
    case pending(defCtx: DefCtx, val: Expr)
  }

  let type: Type
  var typesToMorphs: [Type:Morph]

  init(type: Type, typesToMorphs: [Type:Morph]) {
    self.type = type
    self.typesToMorphs = typesToMorphs
  }

  func lazilyEmitMorph(globalCtx: GlobalCtx, sym: Sym, hostName: String, type: Type) -> String { // returns needsLazy.
    let morphHostName = "\(hostName)__\(type.globalIndex)"
    if let morph = typesToMorphs[type] {
      if case .pending(let defCtx, let val) = morph { // Not yet emitted; do so now.
        typesToMorphs[type] = .compiled
        let needsLazy = compileVal(defCtx: defCtx, hostName: morphHostName, val: val, type: type)
        assert(!needsLazy)
      }
    } else { // synthesize morph.
      typesToMorphs[type] = .compiled
      guard case .sig(let dom, _) = type.kind else { sym.fatal("unexpected synthesized morph type: \(type)") }
      guard case .any(let domMembers) = dom.kind else { sym.fatal("unexpected synthesized morph domain: \(dom)") }
      let em = Emitter(ctx: globalCtx)
      let tableName = "\(morphHostName)__$table" // bling: $table: dispatch table.
      em.str(0, "const \(tableName) = {")
      overDoms: for domMember in domMembers { // lazily emit all necessary concrete morphs for this synthesized morph.
        for morphType in typesToMorphs.keys {
          if morphType.sigDom == domMember {
            let memberHostName = lazilyEmitMorph(globalCtx: globalCtx, sym: sym, hostName: hostName, type: morphType)
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
