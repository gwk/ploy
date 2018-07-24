// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func type(_ scope: Scope, _ subj: String) -> Type {
    // evaluate `self` as a type expression.
    switch self {

    case .intersect(let intersect):
      let l = intersect.left.type(scope, "intersect left operand")
      let r = intersect.right.type(scope, "intersect right operand")
      do { return try Type.All([l, r].sorted()) }
      catch let e { form.failType((e as! String)) }

    case .paren(let paren):
      if paren.isScalarType {
        return paren.els[0].type(scope, subj)
      }
      var posFields = [Type]()
      var labFields = [TypeLabField]()
      var variants = [TypeVariant]()
      var firstLabeledForm: Form? = nil
      var firstVariantForm: Form? = nil
      for par in paren.els {
        switch par.getTypeMember(scope) {
        case .variant(let variant):
          variants.append(variant)
          if firstVariantForm == nil {
            firstVariantForm = par.form
          }
        case .posField(let posField):
          if let first = firstVariantForm {
            par.failSyntax("struct positional field cannot follow a variant.",
              notes: (first, "first variant is here."))
          }
          if let first = firstLabeledForm {
            par.failSyntax("struct positional field cannot follow a labeled field.",
              notes: (first, "first labeled field is here."))
          }
          posFields.append(posField)
        case .labField(let labField):
          if let first = firstVariantForm {
            par.failSyntax("struct labeled field cannot follow a variant.",
              notes: (first, "first variant is here."))
          }
          labFields.append(labField)
          if firstLabeledForm == nil {
            firstLabeledForm = par.form
          }
        }
      }
      return Type.Struct(posFields: posFields, labFields: labFields, variants: variants)

    case .path(let path):
      return scope.typeBinding(path: path, subj: subj)

    case .reif(let reif):
      let abstractType = reif.abstract.type(scope, "reification abstract type")
      return reify(scope, type: abstractType, typeArgs: reif.args)

    case .sig(let sig):
      return Type.Sig(dom: sig.dom.type(scope, "signature domain"), ret: sig.ret.type(scope, "signature return"))

    case .sym(let sym):
      return scope.typeBinding(sym: sym, subj: subj)

    case .typeVar(let typeVar):
      let sym = typeVar.sym
      let type = Type.Var(sym.name)
      _ = scope.addRecord(sym: sym, kind: .type(type))
      return Type.Var(sym.name)

    case .union(let union):
      let l = union.left.type(scope, "union left operand")
      let r = union.right.type(scope, "union right operand")
      do { return try Type.Any_([l, r].sorted()) }
      catch let e { form.failType(e as! String) }

    default:
      form.failType("\(subj) expected a type; received \(form.syntaxName).")
    }
  }


  func getTypeMember(_ scope: Scope) -> TypeMember {
    var isVariant = false
    var label: String? = nil
    var type = typeVoid

    func handle(ann: Ann) -> TypeMember {
      switch ann.expr {
      case .sym(let sym):
        return .labField(TypeLabField(label: sym.name, type: ann.typeExpr.type(scope, "parameter type"))) // TODO: change to "field type".
      case .tag(let tag):
        return .variant(TypeVariant(label: tag.sym.name, type: ann.typeExpr.type(scope, "variant type")))
      default: ann.expr.failSyntax("annotated parameter requires a symbol or tag label.")
      }
    }

    switch self {

    case .ann(let ann): return handle(ann: ann)

    case .bind(let bind):
      switch bind.place {
      case .ann(let ann):
        let _ = handle(ann: ann)
        fatalError("TODO: handle default value.")
      case .sym(let sym): // infer type from default expression.
        let _ = sym.name
        fatalError("TODO: handle default value.")
      case .tag(let tag): // infer type from default expression.
        let _ = tag.sym.name
        fatalError("TODO: handle default value.")
      }

    case .tag(let tag): // bare tag; no payload.
      return .variant(TypeVariant(label: tag.sym.name, type: typeNull))

    default:
      return .posField(self.type(scope, "parameter type"))
    }
  }


  func reify(_ scope: Scope, type: Type, typeArgs: TypeArgs) -> Type {
    // Note: self is the "abstract" value-expr or type-expr.
    var substitutions: [String:Type] = [:]
    for arg in typeArgs.exprs {
      switch arg.typeMemberForTypeArg(scope) {
      case .posField:
        arg.form.failType("positional arguments for types are not yet supported.")
      case .labField(let labField):
        let label = labField.label
        substitutions.insertNewOrElse(label, value: labField.type) {
          arg.form.failType("type argument has duplicate label: `\(label)`")
        }
      case .variant:
        arg.form.failType("variant arguments for types are not supported.") // Possible?
      }
    }
    // Check that substitution is possible first, because recursive substitution process cannot.
    let varNames = type.varNames
    for name in substitutions.keys {
      if !varNames.contains(name) {
        form.failType("type does not contain specified type argument: \(name)")
      }
    }
    return type.reify(substitutions)
  }


  func typeMemberForTypeArg(_ scope: Scope) -> TypeMember {
    switch self {
    case .bind(let bind):
      return .labField(TypeLabField(label: self.argLabel!, type: bind.val.type(scope, "type argument")))
    default:
      return .posField(self.type(scope, "type argument"))
    }
  }
}
