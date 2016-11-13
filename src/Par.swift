// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Par: Form { // compound parameter.

  let label: Sym?
  let typeExpr: Expr? // typeExpr and dflt cannot both be set. // TODO: use Either enum?
  let dflt: Expr?

  init(_ syn: Syn, label: Sym?, typeExpr: Expr?, dflt: Expr?) {
    self.label = label
    self.typeExpr = typeExpr
    self.dflt = dflt
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    if let label = label {
      label.write(to: &stream, depth + 1)
    }
    if let typeExpr = typeExpr {
      typeExpr.write(to: &stream, depth + 1)
    }
    if let dflt = dflt {
      dflt.write(to: &stream, depth + 1)
    }
  }

  func typeParForPar(_ scope: Scope, index: Int) -> TypePar {
    var type: Type
    if let typeExpr = typeExpr {
      type = typeExpr.type(scope, "parameter type")
    } else if let dflt = dflt {
      guard case .ann(let ann) = dflt else { fatalError() } // previously verified in mk; TEMPORARY.
      type = ann.typeExpr.type(scope, "parameter default type")
    } else {
      fatalError() // enforced by mk.
    }
    return TypePar(index: index, label: label, type: type)
  }

  static func mk(form: Form, subj: String) -> Par {
    var label: Sym? = nil
    var typeExpr: Expr? = nil
    var dflt: Expr? = nil
    if let ann = form as? Ann {
      guard case .sym(let sym) = ann.expr else {
        ann.expr.form.failSyntax("annotated parameter requires a label symbol.")
      }
      label = sym
      typeExpr = ann.typeExpr
    } else if let bind = form as? Bind {
      guard case .ann = bind.val else {
        bind.val.form.failSyntax("default parameter requires an annotated value (TEMPORARY).")
      }
      label = bind.sym
      dflt = bind.val
    } else {
      typeExpr = Expr(form: form, subj: subj)
    }
    return Par(form.syn, label: label, typeExpr: typeExpr, dflt: dflt)
  }
}
