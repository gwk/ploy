// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func type(_ scope: Scope, _ subj: String) -> Type {
    // evaluate `self` as a type expression.
    switch self {

    case .paren(let paren):
      if paren.isScalarType {
        return paren.els[0].type(scope, subj)
      }
      return Type.Cmpd(paren.els.enumerated().map {
        (index, par) in
        return par.typeField(scope, index: index)
      })

    case .path(let path):
      return scope.typeBinding(path: path, subj: subj)

    case .reify:
      fatalError()

    case .sig(let sig):
      return Type.Sig(dom: sig.dom.type(scope, "signature domain"), ret: sig.ret.type(scope, "signature return"))

    case .sym(let sym):
      return scope.typeBinding(sym: sym, subj: subj)

    default:
      form.failType("\(subj) expects a type; received \(form.syntaxName).")
    }
  }


  func typeField(_ scope: Scope, index: Int) -> TypeField {
    var label: String? = nil
    var type: Type

    switch self {
    case .ann(let ann):
      guard case .sym(let sym) = ann.expr else {
        ann.expr.form.failSyntax("annotated parameter requires a label symbol.")
      }
      label = sym.name
      type = ann.typeExpr.type(scope, "parameter annotated type")

    case .bind(let bind):
      switch bind.place {
      case .ann(let ann):
        guard case .sym(let sym) = ann.expr else {
          ann.expr.form.failSyntax("annotated default parameter requires a label symbol.")
        }
        label = sym.name
        type = ann.typeExpr.type(scope, "default parameter annotated type")
      case .sym(let sym):
        // TODO: for now assume the sym refers to a type. This is going to change.
        type = scope.typeBinding(sym: sym, subj: "default parameter type")
      }

    default:
      let typeExpr = Expr(form: form, subj: "parameter type")
      type = typeExpr.type(scope, "parameter type")
    }
    return TypeField(label: label, type: type)
  }
}
