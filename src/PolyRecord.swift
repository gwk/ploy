// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class PolyRecord {

  enum MethodStatus {
    case compiled
    case pending(defCtx: DefCtx, val: Expr)
  }

  let polytype: Type
  let prototype: Type
  let protoVarsToMerged: [String:Type]
  var typesToMethodStatuses: [Type:MethodStatus]

  init(protoSig: Expr, prototype: Type, polytype: Type, typesToMethodStatuses: [Type:MethodStatus]) {
    self.prototype = prototype
    self.polytype = polytype
    self.typesToMethodStatuses = typesToMethodStatuses

    guard case .poly(let members) = polytype.kind else { fatalError("\(polytype)") }
    self.protoVarsToMerged = mapVarsToMergedTypes(protoSig: protoSig, prototype: prototype, members: members)
  }

  func typeForProtoVar(sym: Sym) -> Type {
    if let type = protoVarsToMerged[sym.name] { return type }
    sym.failType("type var `\(sym.name)` not present in polyfn merged signature.")
  }
}


func mapVarsToMergedTypes(protoSig: Expr, prototype: Type, members: [Type]) -> [String:Type] {

  var varsToMethodTypes: [String:[Type]] = [:]

  func _map(_ a: Type, _ b: Type) {
    var varsToTypes: [String:Type] = [:]

    switch (a.kind, b.kind) {

    case (.free, _): fatalError()
    case (_, .free): fatalError()
    case (.host, .host): precondition(a == b, "mapVarsToMergedTypes: failure for host type: \(a) => \(b)")
    case (.prim, .prim): precondition(a == b, "mapVarsToMergedTypes: failure for prim type: \(a) => \(b)")

    case (.var_(let name, _), _):
      if let existing = varsToTypes[name] {
        if existing != b {
          protoSig.failType("polyfn prototype \(protoSig) has conflicting var mappings:\n  \(existing)\n  \(b)")
        }
      } else {
        varsToTypes[name] = b
      }

    case (_, .var_(let name, _)):
      fatalError("mapVarsToMethodTypes failure for var \(name): \(a) => \(b)")

    case (.sig(let domA, let retA), .sig(let domB, let retB)):
      _map(domA, domB)
      _map(retA, retB)

    case (.struct_(let posFieldsA, let labFieldsA, let variantsA), .struct_(let posFieldsB, let labFieldsB, let variantsB)):
      for (posFieldA, posFieldB) in zip(posFieldsA, posFieldsB) {
        _map(posFieldA, posFieldB)
      }
      for (labFieldA, labFieldB) in zip(labFieldsA, labFieldsB) { // TODO: zipExact?
        assert(labFieldA.label == labFieldB.label)
         _map(labFieldA.type, labFieldB.type)
      }
      for (variantA, variantB) in zip(variantsA, variantsB) { // TODO: zipExact?
        assert(variantA.label == variantB.label)
        _map(variantA.type, variantB.type)
      }

    default: fatalError("mapVarsToMethodTypes does not implement case: \(a)  =>  \(b)")
    }

    for (name, type) in varsToTypes {
      if varsToMethodTypes.contains(key: name) {
        varsToMethodTypes[name]!.append(type)
      } else {
        varsToMethodTypes[name] = [type]
      }
    }
  }

  for member in members {
    _map(prototype, member)
  }

  return varsToMethodTypes.mapValues { try! Type.Union($0) }
}
