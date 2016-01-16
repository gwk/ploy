// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable, Comparable {

  enum PropAccessor {
    case Index(Int)
    case Name(String)

    var accessorString: String {
      switch self {
      case Index(let index): return String(index)
      case Name(let string): return string
      }
    }
  }

  enum Kind {
    case All(members: Set<Type>, frees: Set<Type>, vars: Set<Type>)
    case Any(members: Set<Type>, frees: Set<Type>, vars: Set<Type>)
    case Cmpd(pars: [TypePar], frees: Set<Type>, vars: Set<Type>)
    case Enum // TODO: vars
    case Free(index: Int)
    case Host
    case Prim
    case Prop(accessor: PropAccessor, type: Type)
    case Sig(par: Type, ret: Type, frees: Set<Type>, vars: Set<Type>)
    case Struct // TODO: vars
    case Var(name: String)
  }

  static var allTypes: [String: Type] = [:]
  static var allFreeTypes: [Type] = []

  let description: String
  let kind: Kind
  let globalIndex: Int

  private init(_ description: String, _ kind: Kind) {
    self.description = description
    self.kind = kind
    self.globalIndex = Type.allTypes.count
    assert(!Type.allTypes.contains(description))
    Type.allTypes[description] = self
  }
  
  class func All(members: Set<Type>) -> Type {
    let description = members.count > 0 ? "All<\(members.map({$0.description}).sort().joinWithSeparator(" "))>" : "Every"
    return allTypes[description].or(Type(description, .All(members: members,
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars }))))
  }

  class func Any(members: Set<Type>) -> Type {
    let description = members.count > 0 ? "Any<\(members.map({$0.description}).sort().joinWithSeparator(" "))>" : "Empty"
    return allTypes[description].or(Type(description, .Any(members: members,
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars }))))
  }

  class func Cmpd(pars: [TypePar]) -> Type {
    let description = "<\(pars.map({$0.description}).sort().joinWithSeparator(" "))>"
    return allTypes[description].or(Type(description, .Cmpd(pars: pars,
      frees: Set(pars.flatMap { $0.type.frees }),
      vars: Set(pars.flatMap { $0.type.vars }))))
  }

  class func Enum(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joinWithSeparator("/")
    return Type(description, .Enum)
  }

  class func Free(index: Int) -> Type { // should only be called by TypeCtx.addFreeType.
    if index < allFreeTypes.count {
      return allFreeTypes[index]
    }
    assert(index == allFreeTypes.count)
    let description = "*\(index)"
    let t = Type(description, .Free(index: index))
    allFreeTypes.append(t)
    return t
  }

  class func Host(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joinWithSeparator("/")
    return Type(description, .Host)
  }

  class func Prim(name: String) -> Type {
    return Type(name, .Prim)
  }

  class func Prop(accessor: PropAccessor, type: Type) -> Type {
    let description = ("\(accessor.accessorString)@\(type)")
    return Type(description, .Prop(accessor: accessor, type: type))
  }

  class func Sig(par par: Type, ret: Type) -> Type {
    let description = "\(par.nestedSigDescription)%\(ret.nestedSigDescription)"
    return allTypes[description].or(Type(description, .Sig(par: par, ret: ret,
      frees: Set(seqs: [par.frees, ret.frees]),
      vars: Set(seqs: [par.vars, ret.vars]))))
  }

  class func Struct(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joinWithSeparator("/")
    return Type(description, .Struct)
  }

  class func Var(name: String) -> Type {
    let description = "*" + name
    return Type(description, .Var(name: name))
  }

  var nestedSigDescription: String {
    switch kind {
    case .Sig: return "(\(description))"
    default: return description
    }
  }

  var frees: Set<Type> {
    switch kind {
    case .All(_ , let frees, _): return frees
    case .Any(_ , let frees, _): return frees
    case .Cmpd(_ , let frees, _): return frees
    case .Enum: return []
    case .Free: return [self]
    case .Host: return []
    case .Prim: return []
    case .Prop(_, let type): return type.frees
    case .Sig(_, _, let frees, _): return frees
    case .Struct: return []
    case .Var: return []
    }
  }

  var vars: Set<Type> {
    switch kind {
    case .All(_ , _, let vars): return vars
    case .Any(_ , _, let vars): return vars
    case .Cmpd(_ , _, let vars): return vars
    case .Enum: return [] // TODO: vars.
    case .Free: return []
    case .Host: return []
    case .Prim: return []
    case .Prop(_, let type): return type.vars
    case .Sig(_, _, _, let vars): return vars
    case .Struct: return [] // TODO: vars.
    case .Var: return [self]
    }
  }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var sigPar: Type {
    if case .Sig(let par, _, _, _) = kind { return par }
    fatalError()
  }

  var sigRet: Type {
    if case .Sig(_, let ret, _, _) = kind { return ret }
    fatalError()
  }

  func refine(target: Type, with replacement: Type) -> Type {
    switch kind {
    case .Free, .Var: return (self == target) ? replacement : self
    case .All(let members, let frees, let vars):
      if frees.contains(target) || vars.contains(target) {
        return Type.All(Set(members.map { self.refine($0, with: replacement) }))
      } else { return self }
    case .Any(let members, let frees, let vars):
      if frees.contains(target) || vars.contains(target) {
        return Type.Any(Set(members.map { self.refine($0, with: replacement) }))
      } else { return self }
    case .Cmpd(let pars, let frees, let vars):
      if frees.contains(target) || vars.contains(target) {
        return Type.Cmpd(pars.map() { self.refinePar($0, replacement: replacement) })
      } else { return self }
    case .Sig(let par, let ret, let frees, let vars):
      if frees.contains(target) || vars.contains(target) {
        return Type.Sig(par: refine(par, with: replacement), ret: refine(ret, with: replacement))
      } else { return self }
    case .Enum: return self // TODO: vars.
    case .Struct: return self // TODO: vars.
    default: return self
    }
  }

  func refinePar(par: TypePar, replacement: Type) -> TypePar {
    let type = refine(par.type, with: replacement)
    return (type == par.type) ? par : TypePar(index: par.index, label: par.label, type: type)
  }
}

func ==(l: Type, r: Type) -> Bool { return l === r }

func <(l: Type, r: Type) -> Bool { return l.description < r.description }


let typeEmpty = Type.Any([]) // aka "Bottom type".
let typeEvery = Type.All([]) // aka "Top type".
let typeVoid = Type.Cmpd([])

let typeBool      = Type.Prim("Bool")
let typeInt       = Type.Prim("Int")
let typeNamespace = Type.Prim("Namespace")
let typeStr       = Type.Prim("Str")
let typeType      = Type.Prim("Type")

let intrinsicTypes = [
  typeBool,
  typeEmpty,
  typeEvery,
  typeInt,
  typeNamespace,
  typeStr,
  typeType,
]
