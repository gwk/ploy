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
            par.failSyntax("struct field cannot follow a variant",
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
    var type = typeVoid

    func handle(ann: Ann) {
      switch ann.expr {
      case .sym(let sym):
        label = sym.name
        type = ann.typeExpr.type(scope, "parameter type")
      case .tag(let tag):
        isVariant = true
        label = tag.sym.name
        type = ann.typeExpr.type(scope, "variant type")
      default: ann.expr.failSyntax("annotated parameter requires a symbol or tag label.")
      }
    }

    switch self {

    case .ann(let ann): handle(ann: ann)

    case .bind(let bind):
      switch bind.place {
      case .ann(let ann):
        handle(ann: ann)
        fatalError("TODO: handle default value.")
      case .sym(let sym): // infer type from default expression.
        label = sym.name
        type = typeVoid // TODO
        fatalError("TODO: handle default value.")
      case .tag(let tag): // infer type from default expression.
        label = tag.sym.name
        type = typeVoid // TODO
        fatalError("TODO: handle default value.")
      }

    case .tag(let tag): // bare tag; no payload.
      isVariant = true
      label = tag.sym.name
      type = typeVoid

    default:
      type = self.type(scope, "parameter type")
    }
    return TypeField(isVariant: isVariant, label: label, type: type)
  }
}
