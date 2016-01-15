// © 2016 George King. Permission to use this file is granted in license.txt.


class TypeCtx {
  private var freeTypes = [Type]()
  private var constraints = [(Type, Type)]()
  private var inferredTypes = [Type:Type]() // maps unrefined types to their partially or completely refined types.
  private var unrefinedTypes = SetDict<Type, Type>() // maps free instances to all types containing them.
  private var formTypes = [_Form:Type]() // maps forms to types.
  private var formScopes = [_Form:Scope]()

  deinit {
    for type in freeTypes {
      guard let inferred = inferredTypes[type] else {
        fatalError("TypeCtx deinitialized with uninferred free type: \(type)")
      }
      if case .Free = inferred.kind {
        fatalError("TypeCtx deinitialized with free type inferred to free type: \(type) -> \(inferred)")
      }
    }
    for set in unrefinedTypes.values {
      for type in set {
        if !type.frees.isEmpty {
          fatalError("TypeCtx deinitialized with unrefined type: \(type); contains free types: \(type.frees)")
        }
      }
    }
  }

  func typeForForm(form: Form) -> Type {
    return formTypes[form as! _Form]!
  }

  func putForm(form: Form, scope: Scope) {
    formScopes[form as! _Form] = scope
  }

  func addConstraint(a: Type, _ b: Type) {
    constraints.append((a, b))
  }

  func addFreeType() -> Type {
    let t = Type.Free(freeTypes.count)
    freeTypes.append(t)
    return t
  }

  func addFreeTypeSig(ret ret: Type) -> Type {
    return Type.Sig(par: addFreeType(), ret: ret)
  }

  func ack(type: Type) {
    for free in type.frees {
      unrefinedTypes.insert(free, member: type)
    }
  }

  func _refine(exp: Type, act: Type) -> Bool { // called only by Form.refine and recursively.
    if exp == act { return true }

    //if let inferred = inferredTypes[exp] {}
    switch exp.kind {
    case .All(let members, _, _):
      switch act.kind {
      case .All(let actMembers, _, _): return members.isSubsetOf(actMembers)
      default: return members.all { self._refine($0, act: act) }
      }
    case .Any(let members, _, _):
      switch act.kind {
      case .Any(let actMembers, _, _): return members.isSupersetOf(actMembers)
      default: return members.any { self._refine($0, act: act) }
      }
    case .Cmpd(let pars, _, _):
      switch act.kind {
      case .Cmpd(let actPars, _, _): return allZip(pars, actPars) { self.refineTypePar($0, act: $1) }
      default: return false
      }
    case .Sig(let par, let ret, _, _):
      switch act.kind {
      case .Sig(let actPar, let actRet, _, _):
        return _refine(par, act: actPar) && _refine(ret, act: actRet)
      default: return false
      }
    default: return false
    }
  }

  private func refineTypePar(exp: TypePar, act: TypePar) -> Bool {
    return exp.index == act.index && exp.label?.name == act.label?.name && _refine(exp.type, act: act.type)
  }
}

