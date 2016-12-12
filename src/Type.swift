// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct TypeSig {
  let send: Type
  let ret: Type
  let frees: Set<Type>
  let vars: Set<Type>
}


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
    case cmpd(pars: [TypeField], frees: Set<Type>, vars: Set<Type>)
    case enum_ // TODO: vars
    case free(index: Int)
    case host
    case prim
    case prop(accessor: PropAccessor, type: Type)
    case sig(TypeSig)
    case struct_ // TODO: vars
    case var_(name: String)
  }

  static var allTypes: [String: Type] = [:]
  static var allFreeTypes: [Type] = []

  let description: String
  let kind: Kind
  let globalIndex: Int

  private init(_ description: String, kind: Kind) {
    self.description = description
    self.kind = kind
    self.globalIndex = Type.allTypes.count
    assert(!Type.allTypes.contains(key: description), "type already exists with description: \(description)")
    Type.allTypes[description] = self
  }

  class func memoize(_ description: String, _ kind: @autoclosure ()->Kind) -> Type {
    return allTypes[description].or(Type(description, kind: kind()))
  }

  class func All(_ members: Set<Type>) -> Type {
    let description = members.isEmpty ? "Every" : "All<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return memoize(description, .all(members: members,
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Any_(_ members: Set<Type>) -> Type {
    let description = members.isEmpty ? "Empty" : "Any_<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return memoize(description, .any(members: members,
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Cmpd(_ pars: [TypeField]) -> Type {
    let descs = pars.map({$0.description}).joined(separator: " ")
    let description = "(\(descs))"
    return memoize(description, .cmpd(pars: pars,
      frees: Set(pars.flatMap { $0.type.frees }),
      vars: Set(pars.flatMap { $0.type.vars })))
  }

  class func Enum(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joined(separator: "/")
    return Type(description, kind: .enum_)
  }

  class func Free(_ index: Int) -> Type { // should only be called by TypeCtx.addFreeType.
    if index < allFreeTypes.count {
      return allFreeTypes[index]
    }
    assert(index == allFreeTypes.count)
    let description = "*\(index)"
    let t = Type(description, kind: .free(index: index))
    allFreeTypes.append(t)
    return t
  }

  class func Host(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joined(separator: "/")
    return Type(description, kind: .host)
  }

  class func Prim(_ name: String) -> Type {
    return Type(name, kind: .prim)
  }

  class func Prop(_ accessor: PropAccessor, type: Type) -> Type {
    let description = ("\(accessor.accessorString)@\(type)")
    return memoize(description, .prop(accessor: accessor, type: type))
  }

  class func Sig(send: Type, ret: Type) -> Type {
    let description = "\(send.nestedSigDescription)%\(ret.nestedSigDescription)"
    return memoize(description, .sig(TypeSig(send: send, ret: ret,
      frees: Set(sequences: [send.frees, ret.frees]),
      vars: Set(sequences: [send.vars, ret.vars]))))
  }

  class func Struct(spacePathNames names: [String], sym: Sym) -> Type {
    let description = (names + [sym.name]).joined(separator: "/")
    return Type(description, kind: .struct_)
  }

  class func Var(_ name: String) -> Type {
    let description = "*" + name
    return Type(description, kind: .var_(name: name))
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
    case .sig(let sig): return sig.frees
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
    case .sig(let sig): return sig.vars
    case .struct_: return [] // TODO: vars.
    case .var_: return [] // does not return self.
    }
  }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

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
    case .sig(let sig):
      if sig.frees.contains(target) || sig.vars.contains(target) {
        return Type.Sig(send: refine(sig.send, with: replacement), ret: refine(sig.ret, with: replacement))
      } else { return self }
    case .enum_: return self // TODO: vars.
    case .struct_: return self // TODO: vars.
    default: return self
    }
  }

  private func refine(par: TypeField, replacement: Type) -> TypeField {
    let type = refine(par.type, with: replacement)
    return (type == par.type) ? par : TypeField(index: par.index, label: par.label, type: type)
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

let intrinsicTypes = [
  typeBool,
  typeEmpty,
  typeEvery,
  typeInt,
  typeNamespace,
  typeStr,
  typeType,
]
