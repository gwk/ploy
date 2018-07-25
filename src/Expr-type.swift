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
      return mkStructType(isLiteral: false, exprs: paren.els) {
        $0.typeMemberForType(scope)
      }

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


  func typeMemberForType(_ scope: Scope) -> TypeMember {
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
      switch arg.typeMemberForReification(scope) {
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


  func typeMemberForReification(_ scope: Scope) -> TypeMember {
    switch self {
    case .bind(let bind):
      return .labField(TypeLabField(label: self.argLabel!, type: bind.val.type(scope, "type argument")))
    default:
      return .posField(self.type(scope, "type argument"))
    }
  }
}


func mkStructType(isLiteral: Bool, exprs:[Expr], getTypeMember: (Expr)->TypeMember) -> Type {
  let tagTerm = (isLiteral ? "morph" : "variant")
  var posFields = [Type]()
  var labFields = [TypeLabField]()
  var variants = [TypeVariant]()
  var labExprs: [String:Expr] = [:]
  var firstLab: Expr? = nil
  var firstTag: Expr? = nil
  for expr in exprs {
    switch getTypeMember(expr) {
    case .posField(let posField):
      if let firstTag = firstTag {
        expr.failSyntax("positional field cannot follow a \(tagTerm) tag.",
          notes: (firstTag.form, "first tag is here."))
      }
      if let firstLab = firstLab {
        expr.failSyntax("positional field cannot follow a labeled field.",
          notes: (firstLab.form, "first label is here."))
      }
      posFields.append(posField)
    case .labField(let labField):
      if let firstTag = firstTag {
        expr.failSyntax("labeled field cannot follow a \(tagTerm) tag.",
          notes: (firstTag.form, "first tag is here."))
      }
      if let prev = labExprs[labField.label] {
        expr.failSyntax("label is repeated.",
          notes: (prev.form, "label previously appeared here"))
      }
      labExprs[labField.label] = expr
      labFields.append(labField)
      if firstLab == nil {
        firstLab = expr
      }
    case .variant(let variant):
      if let firstTag = firstTag {
        if isLiteral {
          expr.failSyntax("struct literal cannot contain multiple morph tags.",
            notes: (firstTag.form, "first tag is here"))
        }
      } else {
        firstTag = expr
      }
      if let prev = labExprs[variant.label] {
        expr.failSyntax("label is repeated.",
          notes: (prev.form, "label previously appeared here"))
      }
      labExprs[variant.label] = expr
      variants.append(variant)
    }
  }
  return Type.Struct(posFields: posFields, labFields: labFields, variants: variants)
}
