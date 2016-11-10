// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable, Comparable {

  enum PropAccessor {
    case index(Int)
    case name(String)

    var accessorString: String {
      switch self {
      case .index(let index): return String(index)
      case .name(let string): return string
      }
    }
  }

  enum Kind {
    case all(members: Set<Type>, frees: Set<Type>, vars: Set<Type>)
    case any(members: Set<Type>, frees: Set<Type>, vars: Set<Type>)
    case cmpd(pars: [TypePar], frees: Set<Type>, vars: Set<Type>)
    case enum_ // TODO: vars
    case free(index: Int)
    case host
    case prim
    case prop(accessor: PropAccessor, type: Type)
    case sig(par: Type, ret: Type, frees: Set<Type>, vars: Set<Type>)
    case struct_ // TODO: vars
    case var_(name: String)
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
    assert(!Type.allTypes.contains(key: description))
    Type.allTypes[description] = self
  }

  class func All(_ members: Set<Type>) -> Type {
    let description = members.isEmpty ? "Every" : "All<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return allTypes[description].or(Type(description, .all(members: members,
        frees: Set(members.flatMap { $0.frees }),
        vars: Set(members.flatMap { $0.vars }))))
  }

  class func Any_(_ members: Set<Type>) -> Type {
    let description = members.isEmpty ? "Empty" : "Any_<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return allTypes[description].or(Type(description, .any(members: members,
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars }))))
  }

  class func Cmpd(_ pars: [TypePar]) -> Type {
    let description = "<\(pars.map({$0.description}).joined(separator: " "))>"
    return allTypes[description].or(Type(description, .cmpd(pars: pars,
      frees: Set(pars.flatMap { $0.type.frees }),
      vars: Set(pars.flatMap { $0.type.vars }))))
  }

  class func Enum(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joined(separator: "/")
    return Type(description, .enum_)
  }

  class func Free(_ index: Int) -> Type { // should only be called by TypeCtx.addFreeType.
    if index < allFreeTypes.count {
      return allFreeTypes[index]
    }
    assert(index == allFreeTypes.count)
    let description = "*\(index)"
    let t = Type(description, .free(index: index))
    allFreeTypes.append(t)
    return t
  }

  class func Host(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joined(separator: "/")
    return Type(description, .host)
  }

  class func Prim(_ name: String) -> Type {
    return Type(name, .prim)
  }

  class func Prop(_ accessor: PropAccessor, type: Type) -> Type {
    let description = ("\(accessor.accessorString)@\(type)")
    return Type(description, .prop(accessor: accessor, type: type))
  }

  class func Sig(par: Type, ret: Type) -> Type {
    let description = "\(par.nestedSigDescription)%\(ret.nestedSigDescription)"
    return allTypes[description].or(Type(description, .sig(par: par, ret: ret,
      frees: Set(sequences: [par.frees, ret.frees]),
      vars: Set(sequences: [par.vars, ret.vars]))))
  }

  class func Struct(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joined(separator: "/")
    return Type(description, .struct_)
  }

  class func Var(_ name: String) -> Type {
    let description = "*" + name
    return Type(description, .var_(name: name))
  }

  var nestedSigDescription: String {
    switch kind {
    case .sig: return "(\(description))"
    default: return description
    }
  }

  var frees: Set<Type> {
    switch kind {
    case .all(_ , let frees, _): return frees
    case .any(_ , let frees, _): return frees
    case .cmpd(_ , let frees, _): return frees
    case .enum_: return []
    case .free: return [] // does not return self.
    case .host: return []
    case .prim: return []
    case .prop(_, let type): return type.frees
    case .sig(_, _, let frees, _): return frees
    case .struct_: return []
    case .var_: return []
    }
  }

  var vars: Set<Type> {
    switch kind {
    case .all(_ , _, let vars): return vars
    case .any(_ , _, let vars): return vars
    case .cmpd(_ , _, let vars): return vars
    case .enum_: return [] // TODO: vars.
    case .free: return []
    case .host: return []
    case .prim: return []
    case .prop(_, let type): return type.vars
    case .sig(_, _, _, let vars): return vars
    case .struct_: return [] // TODO: vars.
    case .var_: return [] // does not return self.
    }
  }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var sigPar: Type {
    if case .sig(let par, _, _, _) = kind { return par }
    fatalError()
  }

  var sigRet: Type {
    if case .sig(_, let ret, _, _) = kind { return ret }
    fatalError()
  }

  var freeIndex: Int {
    if case .free(let index) = kind { return index }
    fatalError()
  }

  func refine(_ target: Type, with replacement: Type) -> Type {
    // within the receiver type, replace target type with replacement, returning a new type.
    switch kind {
    case .free, .var_: return (self == target) ? replacement : self
    case .all(let members, let frees, let vars):
      if frees.contains(target) || vars.contains(target) {
        return Type.All(Set(members.map { self.refine($0, with: replacement) }))
      } else { return self }
    case .any(let members, let frees, let vars):
      if frees.contains(target) || vars.contains(target) {
        return Type.Any_(Set(members.map { self.refine($0, with: replacement) }))
      } else { return self }
    case .cmpd(let pars, let frees, let vars):
      if frees.contains(target) || vars.contains(target) {
        return Type.Cmpd(pars.map() { self.refine(par: $0, replacement: replacement) })
      } else { return self }
    case .sig(let par, let ret, let frees, let vars):
      if frees.contains(target) || vars.contains(target) {
        return Type.Sig(par: refine(par, with: replacement), ret: refine(ret, with: replacement))
      } else { return self }
    case .enum_: return self // TODO: vars.
    case .struct_: return self // TODO: vars.
    default: return self
    }
  }

  private func refine(par: TypePar, replacement: Type) -> TypePar {
    let type = refine(par.type, with: replacement)
    return (type == par.type) ? par : TypePar(index: par.index, label: par.label, type: type)
  }
}

func ==(l: Type, r: Type) -> Bool { return l === r }

func <(l: Type, r: Type) -> Bool { return l.description < r.description }


let typeEmpty = Type.Any_([]) // aka "Bottom type".
let typeEvery = Type.All([]) // aka "Top type".
let typeVoid = Type.Cmpd([])

let typeBool      = Type.Prim("Bool")
let typeInt       = Type.Prim("Int")
let typeNamespace = Type.Prim("Namespace")
let typeStr       = Type.Prim("Str")
let typeType      = Type.Prim("Type")

let typeOfMainFn = Type.Sig(par: typeVoid, ret: typeVoid)

let intrinsicTypes = [
  typeBool,
  typeEmpty,
  typeEvery,
  typeInt,
  typeNamespace,
  typeStr,
  typeType,
]
