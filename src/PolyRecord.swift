// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class PolyRecord {

  enum MethodStatus {
    case compiled
    case pending(defCtx: DefCtx, val: Expr)
  }

  let polytype: Type
  var typesToMethodStatuses: [Type:MethodStatus]

  init(polytype: Type, typesToMethodStatuses: [Type:MethodStatus]) {
    self.polytype = polytype
    self.typesToMethodStatuses = typesToMethodStatuses
  }

  func lazilyEmitMethod(globalCtx: GlobalCtx, sym: Sym, hostName: String, type: Type) -> String {
    let methodHostName = "\(hostName)__\(type.globalIndex)"
    if let method = typesToMethodStatuses[type] {
      if case .pending(let defCtx, let val) = method { // Not yet emitted; do so now.
        typesToMethodStatuses[type] = .compiled
        let needsLazy = compileVal(defCtx: defCtx, hostName: methodHostName, val: val, type: type)
        assert(!needsLazy)
      }
    } else { // synthesize method.
      typesToMethodStatuses[type] = .compiled
      guard case .sig(let dom, _) = type.kind else { sym.fatal("unexpected synthesized method type: \(type)") }
      guard case .any(let domMembers) = dom.kind else { sym.fatal("unexpected synthesized method domain: \(dom)") }
      let em = Emitter(ctx: globalCtx)
      let tableName = "\(methodHostName)__$table" // bling: $table: dispatch table.
      em.str(0, "const \(tableName) = {")
      overDoms: for domMember in domMembers { // lazily emit all necessary concrete methods for this synthesized method.
        for methodType in typesToMethodStatuses.keys {
          if methodType.sigDom == domMember {
            let memberHostName = lazilyEmitMethod(globalCtx: globalCtx, sym: sym, hostName: hostName, type: methodType)
            em.str(2, "'\(domMember)': \(memberHostName),")
            continue overDoms
          }
        }
        sym.fatal("synthesizing method \(type): no match for domain member: \(domMember); searched \(Array(typesToMethodStatuses.keys))")
      }
      em.append("};") // close table.
      em.str(0, "const \(methodHostName) = $=>\(tableName)[$.$u]($.$m); // \(type)")
      em.flush()
    }
    return methodHostName
  }
}
