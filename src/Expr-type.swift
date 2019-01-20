// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func type(_ scope: LocalScope, _ subj: String) -> Type {
    // evaluate `self` as a type expression.
    switch self {

    case .acc(let acc):
      guard case .sym(let sym) = acc.accessor else {
        acc.accessor.failSyntax("type accessor must be a symbol.")
      }
      let identifier:Identifier
      switch acc.accessee {
      case .sym(let sym): identifier = .sym(sym)
      case .path(let path): identifier = .path(path)
      default: acc.accessee.failType("type accessee must be either a symbol or path.")
      }
      let rec = scope.getRecord(identifier: identifier)
      switch rec.kind {
      case .poly(let polyRec):
        acc.accessee.fatal("type access not yet implemented; polyRec.polytype: \(polyRec.polytype)")
      default: acc.accessee.failType("type accessee must refer to a polyfn.")
      }

    case .intersection(let intersection):
      let l = intersection.left.type(scope, "intersection left operand")
      let r = intersection.right.type(scope, "intersection right operand")
      do { return try Type.All([l, r].sorted()) }
      catch let e { failType((e as! String)) }

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
      let reqType = typeVar.requirement.type(scope, "type var requirement")
      let type = Type.Var(name: sym.name, requirement: reqType)
      _ = scope.addRecord(sym: sym, kind: .type(type))
      return Type.Var(name: sym.name, requirement: reqType)

    case .union(let union):
      let l = union.left.type(scope, "union left operand")
      let r = union.right.type(scope, "union right operand")
      do { return try Type.Any_([l, r].sorted()) }
      catch let e { failType(e as! String) }

    case .where_(let where_):
      let base = where_.base.type(scope, "refinement base")
      let pred = where_.pred // TODO: this needs to be a symbol resolving to a def or something.
      return Type.Refinement(base: base, pred: pred)

    default:
      failType("\(subj) expected a type; received \(actDesc).")
    }
  }


  func typeMemberForType(_ scope: LocalScope) -> TypeMember {
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


  func typeMemberForReification(_ scope: LocalScope) -> TypeMember {
    switch self {
    case .bind(let bind):
      return .labField(TypeLabField(label: self.argLabel!, type: bind.val.type(scope, "type argument")))
    default:
      return .posField(self.type(scope, "type argument"))
    }
  }


  func reify(_ scope: LocalScope, type: Type, typeArgs: TypeArgs) -> Type {
    // Note: self is the "abstract" value-expr or type-expr.
    var substitutions: [String:Type] = [:]
    for arg in typeArgs.exprs {
      switch arg.typeMemberForReification(scope) {
      case .posField:
        arg.failType("positional arguments for types are not yet supported.")
      case .labField(let labField):
        let label = labField.label
        substitutions.insertNewOrElse(label, value: labField.type) {
          arg.failType("type argument has duplicate label: `\(label)`")
        }
      case .variant:
        arg.failType("variant arguments for types are not supported.") // Possible?
      }
    }
    // Check that substitution is possible first, because recursive substitution process cannot.
    let varNames = type.varNames
    for name in substitutions.keys {
      if !varNames.contains(name) {
        failType("type does not contain specified type argument: \(name)")
      }
    }
    return type.substitute(substitutions)
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
          notes: (firstTag, "first tag is here."))
      }
      if let firstLab = firstLab {
        expr.failSyntax("positional field cannot follow a labeled field.",
          notes: (firstLab, "first label is here."))
      }
      posFields.append(posField)
    case .labField(let labField):
      if let firstTag = firstTag {
        expr.failSyntax("labeled field cannot follow a \(tagTerm) tag.",
          notes: (firstTag, "first tag is here."))
      }
      if let prev = labExprs[labField.label] {
        expr.failSyntax("label is repeated.",
          notes: (prev, "label previously appeared here"))
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
            notes: (firstTag, "first tag is here"))
        }
      } else {
        firstTag = expr
      }
      if let prev = labExprs[variant.label] {
        expr.failSyntax("label is repeated.",
          notes: (prev, "label previously appeared here"))
      }
      labExprs[variant.label] = expr
      variants.append(variant)
    }
  }
  return Type.Struct(posFields: posFields, labFields: labFields, variants: variants)
}
