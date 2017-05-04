// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable, Comparable {

  enum Kind {
    case all(members: Set<Type>)
    case any(members: Set<Type>)
    case struct_(fields: [TypeField])
    case free(index: Int)
    case host
    case poly(members: Set<Type>)
    case prim
    case sig(dom: Type, ret: Type)
    case var_(name: String)
  }

  static var allTypes: [String: Type] = [:]
  static var allFreeTypes: [Type] = []

  let globalIndex: Int
  let description: String
  let kind: Kind
  let childFrees: Set<Type>
  let childVars: Set<Type>

  private init(_ description: String, kind: Kind, frees: Set<Type> = [], vars: Set<Type> = []) {
    self.globalIndex = Type.allTypes.count
    self.description = description
    self.kind = kind
    self.childFrees = frees
    self.childVars = vars
    Type.allTypes.insertNew(description, value: self)
  }

  class func memoize(_ description: String, _ parts: @autoclosure ()->(kind: Kind, frees: Set<Type>, vars: Set<Type>)) -> Type {
    if let memo = allTypes[description] {
      return memo
    }
    let (kind, frees, vars) = parts()
    let type = Type(description, kind: kind, frees: frees, vars: vars)
    allTypes[description] = type
    return type
  }

  class func All(_ members: Set<Type>) -> Type {
    let desc = members.isEmpty ? "Every" : "All<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return memoize(desc, (
      kind: .all(members: members),
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Any_(_ members: Set<Type>) -> Type {
    let desc = members.isEmpty ? "Empty" : "Any_<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return memoize(desc, (
      kind: .any(members: members),
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Struct(_ fields: [TypeField]) -> Type {
    let descs = fields.map({$0.description}).joined(separator: " ")
    let desc = "(\(descs))"
    return memoize(desc, (
      kind: .struct_(fields: fields),
      frees: Set(fields.flatMap { $0.type.frees }),
      vars: Set(fields.flatMap { $0.type.vars })))
  }

  class func Free(_ index: Int) -> Type { // should only be called by TypeCtx.addFreeType.
    if index < allFreeTypes.count {
      return allFreeTypes[index]
    }
    assert(index == allFreeTypes.count)
    let desc = "*\(index)"
    let t = Type(desc, kind: .free(index: index))
    allFreeTypes.append(t)
    return t
  }

  class func Host(spacePathNames names: [String], sym: Sym) -> Type {
    let desc = (names + [sym.name]).joined(separator: "/")
    return Type(desc, kind: .host)
  }

  class func Poly(_ members: Set<Type>) -> Type {
    let desc = "Poly<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return memoize(desc, (
      kind: .poly(members: members),
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Prim(_ name: String) -> Type {
    return Type(name, kind: .prim)
  }

  class func Sig(dom: Type, ret: Type) -> Type {
    let desc = "\(dom.nestedSigDescription)%\(ret.nestedSigDescription)"
    return memoize(desc, (
      kind: .sig(dom: dom, ret: ret),
      frees: dom.frees.union(ret.frees),
      vars: dom.vars.union(ret.vars)))
  }

  class func Var(_ name: String) -> Type {
    let desc = "*" + name
    return Type(desc, kind: .var_(name: name))
  }

  var nestedSigDescription: String {
    switch kind {
    case .sig: return "(\(description))"
    default: return description
    }
  }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var freeIndex: Int {
    if case .free(let index) = kind { return index }
    fatalError()
  }

  var frees: Set<Type> {
    var s = childFrees
    if case .free = self.kind { s.insert(self) }
    return s
  }

  var vars: Set<Type> {
    var s = childVars
    if case .var_ = self.kind { s.insert(self) }
    return s
  }

  var isResolved: Bool {
    switch self.kind {
    case .free: return false
    default: return childFrees.isEmpty
    }
  }

  static func ==(l: Type, r: Type) -> Bool { return l === r }

  static func <(l: Type, r: Type) -> Bool { return l.globalIndex < r.globalIndex }

  var sigDom: Type {
    switch self.kind {
    case .sig(let dom, _): return dom
    default: fatalError()
    }
  }

  var sigRet: Type {
    switch self.kind {
    case .sig(_, let ret): return ret
    default: fatalError()
    }
  }
}



let typeEmpty = Type.Any_([]) // aka "Bottom type"; the set of all objects.
let typeEvery = Type.All([]) // aka "Top type"; the empty set.
let typeVoid = Type.Struct([])

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
