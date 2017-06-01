// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func type(_ scope: Scope, _ subj: String) -> Type {
    // evaluate `self` as a type expression.
    switch self {

    case .paren(let paren):
      if paren.isScalarType {
        return paren.els[0].type(scope, subj)
      }
      var fields = [TypeField]()
      var variants = [TypeField]()
      var firstVariantForm: Form? = nil
      for par in paren.els {
        let typeField = par.getTypeField(scope)
        if typeField.isVariant {
          variants.append(typeField)
          if firstVariantForm == nil {
            firstVariantForm = par.form
          }
        } else if let first = firstVariantForm {
            par.form.failSyntax("compound field cannot follow a variant",
              notes: (first, "first variant is here"))
        } else {
          fields.append(typeField)
        }
      }
      return Type.Struct(fields: fields, variants: variants)

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


  func getTypeField(_ scope: Scope) -> TypeField {
    var isVariant = false
    var label: String? = nil
    var type: Type

    switch self {

    case .ann(let ann):
      guard case .sym(let sym) = ann.expr  else {
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

    case .tag(let tag):
      isVariant = true
      guard case .ann(let ann) = tag.tagged else {
        let tagged = tag.tagged.form
        tagged.failSyntax("variant parameter (tag within a type expression) requires an annotation; received \(tagged)")
      }
      label = tag.tagged.sym.name
      type = ann.typeExpr.type(scope, "variant type")

    default:
      type = self.type(scope, "parameter type")
    }
    return TypeField(isVariant: isVariant, label: label, type: type)
  }
}
