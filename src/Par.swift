// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Par: _Form { // compound parameter.
  
  let index: Int
  let label: Sym?
  let typeExpr: TypeExpr? // typeExpr and dflt cannot both be set. // TODO: use Either enum?
  let dflt: Expr?

  init(_ syn: Syn, index: Int, label: Sym?, typeExpr: TypeExpr?, dflt: Expr?) {
    self.index = index
    self.label = label
    self.typeExpr = typeExpr
    self.dflt = dflt
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    if let label = label {
      label.write(to: &stream, depth + 1)
    }
    if let typeExpr = typeExpr {
      typeExpr.write(to: &stream, depth + 1)
    }
    if let dflt = dflt {
      dflt.form.write(to: &stream, depth + 1)
    }
  }
    
  func typeParForPar(_ scope: Scope, _ subj: String) -> TypePar {
    var type: Type
    if let typeExpr = typeExpr {
      type = typeExpr.typeForTypeExpr(scope, "parameter type")
    } else if let dflt = dflt {
      let ann = dflt.form as! Ann // previously verified in mk; TEMPORARY.
      type = ann.typeExpr.typeForTypeExpr(scope, "parameter default type")
    } else {
      fatalError() // enforced by mk.
    }
    return TypePar(index: index, label: label, type: type)
  }
  
  static func mk(index: Int, form: Form, subj: String) -> Par {
    var label: Sym? = nil
    var typeExpr: TypeExpr? = nil
    var dflt: Expr? = nil
    if let ann = form as? Ann {
      guard let sym = ann.expr.form as? Sym else {
        ann.expr.form.failSyntax("annotated parameter requires a label symbol.")
      }
      label = sym
      typeExpr = ann.typeExpr
    } else if let bind = form as? Bind {
      guard let _ = bind.val.form as? Ann else {
        bind.val.form.failSyntax("default parameter requires an annotated value (TEMPORARY).")
      }
      label = bind.sym
      dflt = bind.val
    } else if let t = form as? TypeExpr {
      typeExpr = t
    } else {
      form.failSyntax("\(subj) parameter currently limited to require an explicit type.")
    }
    return Par(form.syn, index: index, label: label, typeExpr: typeExpr, dflt: dflt)
  }
}

