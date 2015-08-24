// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Par: _Form, Form { // parameter.
  
  let hostName: String
  let label: Sym?
  let type: TypeExpr? // type and dflt cannot both be set. // TODO: use Either enum?
  let dflt: Expr?

  init(_ syn: Syn, hostName: String, label: Sym?, type: TypeExpr?, dflt: Expr?) {
    self.hostName = hostName
    self.label = label
    self.type = type
    self.dflt = dflt
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    if let label = label {
      label.writeTo(&target, depth + 1)
    }
    if let type = type {
      type.writeTo(&target, depth + 1)
    }
    if let dflt = dflt {
      dflt.writeTo(&target, depth + 1)
    }
  }
  
  func typeValPar(scope: Scope) -> TypeValPar {
    var typeVal: TypeVal! = nil
    if let type = type {
      typeVal = type.typeVal(scope, "parameter type")
    } else if let dflt = dflt {
      let ann = dflt as! Ann // previously verified in mk; TEMPORARY.
      typeVal = ann.type.typeVal(scope, "parameter default type")
    }
    return TypeValPar(par: self, typeVal: typeVal)
  }
  
  static func mk(index index: Int, form: Form, subj: String) -> Par {
    var label: Sym? = nil
    var type: TypeExpr! = nil
    var dflt: Expr? = nil
    if let ann = form as? Ann {
      guard let sym = ann.val as? Sym else {
        ann.val.failSyntax("annotated parameter requires a label symbol.")
      }
      label = sym
      type = ann.type
    } else if let bind = form as? Bind {
      guard let _ = bind.val as? Ann else {
        bind.val.failSyntax("default parameter requires an annotated value (TEMPORARY).")
      }
      label = bind.sym
      dflt = bind.val
    } else if let t = form as? TypeExpr {
      type = t
    } else {
      form.failSyntax("\(subj) parameter currently limited to require a type.")
    }
    let hostName = (label?.name.dashToUnder).or("_\(index)")
    return Par(form.syn, hostName: hostName, label: label, type: type, dflt: dflt)
  }
}

