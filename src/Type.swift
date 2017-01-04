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
    case all(members: Set<Type>)
    case any(members: Set<Type>)
    case cmpd(fields: [TypeField])
    case conv(orig: Type, cast: Type)
    case free(index: Int)
    case host
    case poly(members: Set<Type>)
    case prim
    case prop(accessor: PropAccessor, type: Type)
    case sig(dom: Type, ret: Type)
    case sub(orig: Type, cast: Type)
    case var_(name: String)
  }

  static var allTypes: [String: Type] = [:]
  static var allFreeTypes: [Type] = []

  let globalIndex: Int
  let description: String
  let kind: Kind
  let childConvs: Set<Type>
  let childFrees: Set<Type>
  let childVars: Set<Type>

  private init(_ description: String, kind: Kind, convs: Set<Type> = [], frees: Set<Type> = [], vars: Set<Type> = []) {
    self.globalIndex = Type.allTypes.count
    self.description = description
    self.kind = kind
    self.childConvs = convs
    self.childFrees = frees
    self.childVars = vars
    Type.allTypes.insertNew(description, value: self)
  }

  class func memoize(_ description: String, _ parts: @autoclosure ()->(kind: Kind, convs: Set<Type>, frees: Set<Type>, vars: Set<Type>)) -> Type {
    if let memo = allTypes[description] {
      return memo
    }
    let (kind, convs, frees, vars) = parts()
    let type = Type(description, kind: kind, convs: convs, frees: frees, vars: vars)
    allTypes[description] = type
    return type
  }

  class func All(_ members: Set<Type>) -> Type {
    let description = members.isEmpty ? "Every" : "All<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return memoize(description, (
      kind: .all(members: members),
      convs: Set(members.flatMap { $0.convs }),
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Any_(_ members: Set<Type>) -> Type {
    let description = members.isEmpty ? "Empty" : "Any_<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return memoize(description, (
      kind: .any(members: members),
      convs: Set(members.flatMap { $0.convs }),
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Cmpd(_ fields: [TypeField]) -> Type {
    let descs = fields.map({$0.description}).joined(separator: " ")
    let description = "(\(descs))"
    return memoize(description, (
      kind: .cmpd(fields: fields),
      convs: Set(fields.flatMap { $0.type.convs }),
      frees: Set(fields.flatMap { $0.type.frees }),
      vars: Set(fields.flatMap { $0.type.vars })))
  }

  class func Conv(orig: Type, cast: Type) -> Type {
    let description = "\(orig.description)~>\(cast.description)"
    return memoize(description, (
      kind: .conv(orig: orig, cast: cast),
      convs: orig.convs.union(cast.convs), // TODO: this sees wrong.
      frees: orig.frees.union(cast.frees),
      vars: orig.vars.union(cast.vars)))
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

  class func Poly(_ members: Set<Type>) -> Type {
    let description = "Poly<\(members.map({$0.description}).sorted().joined(separator: " "))>"
    return memoize(description, (
      kind: .poly(members: members),
      convs: Set(members.flatMap { $0.convs }),
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Prim(_ name: String) -> Type {
    return Type(name, kind: .prim)
  }

  class func Prop(_ accessor: PropAccessor, type: Type) -> Type {
    let description = ("\(accessor.accessorString)@\(type)")
    return memoize(description, (
      kind: .prop(accessor: accessor, type: type),
      convs: type.convs,
      frees: type.frees,
      vars: type.vars))
  }

  class func Sig(dom: Type, ret: Type) -> Type {
    let description = "\(dom.nestedSigDescription)%\(ret.nestedSigDescription)"
    return memoize(description, (
      kind: .sig(dom: dom, ret: ret),
      convs: dom.convs.union(ret.convs),
      frees: dom.frees.union(ret.frees),
      vars: dom.vars.union(ret.vars)))
  }

  class func Sub(orig: Type, cast: Type) -> Type {
    let description = "\(orig.description)->\(cast.description)"
    return memoize(description, (
      kind: .sub(orig: orig, cast: cast),
      convs: orig.convs.union(cast.convs),
      frees: orig.frees.union(cast.frees),
      vars: orig.vars.union(cast.vars)))
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

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var freeIndex: Int {
    if case .free(let index) = kind { return index }
    fatalError()
  }

  var convs: Set<Type> {
    var s = childConvs
    if case .conv = self.kind { s.insert(self) }
    return s
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

  var convFnName: String {
    switch self.kind {
    case .conv(let orig, let cast): return "$c_\(orig.globalIndex)_\(cast.globalIndex)"
    default: fatalError()
    }
  }
}

func ==(l: Type, r: Type) -> Bool { return l === r }

func <(l: Type, r: Type) -> Bool { return l.description < r.description }


let typeEmpty = Type.Any_([]) // aka "Bottom type"; the set of all objects.
let typeEvery = Type.All([]) // aka "Top type"; the empty set.
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
