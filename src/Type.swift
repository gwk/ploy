// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable, Comparable {

  enum Kind {
    case all(members: Set<Type>)
    case any(members: Set<Type>)
    case free(index: Int)
    case host
    case poly(members: Set<Type>)
    case prim
    case sig(dom: Type, ret: Type)
    case struct_(fields: [TypeField], variants: [TypeField])
    case var_(name: String)
    case variantMember(variant: TypeField)
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

  class func Free(_ index: Int) -> Type { // should only be called by TypeCtx.addFreeType.
    if index < allFreeTypes.count {
      return allFreeTypes[index]
    }
    assert(index == allFreeTypes.count)
    let desc = "^\(index)"
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

  fileprivate class func Prim(_ name: String) -> Type {
    return Type(name, kind: .prim)
  }

  class func Sig(dom: Type, ret: Type) -> Type {
    let desc = "\(dom.nestedSigDescription)%\(ret.nestedSigDescription)"
    return memoize(desc, (
      kind: .sig(dom: dom, ret: ret),
      frees: dom.frees.union(ret.frees),
      vars: dom.vars.union(ret.vars)))
  }

  class func Struct(fields: [TypeField], variants: [TypeField]) -> Type {
    let members = fields + variants
    let descs = members.map({$0.description}).joined(separator: " ")
    let desc = "(\(descs))"
    return memoize(desc, (
      kind: .struct_(fields: fields, variants: variants),
      frees: Set(members.flatMap { $0.type.frees }),
      vars:  Set(members.flatMap { $0.type.vars })))
  }

  class func Var(_ name: String) -> Type {
    let desc = "^" + name
    return memoize(desc, (kind: .var_(name: name), frees: [], vars: []))
  }

  class func Variant(label: String, type: Type) -> Type {
    return Struct(fields: [], variants: [TypeField(isVariant: true, label: label, type: type)])
  }

  class func VariantMember(variant: TypeField) -> Type {
    let desc = "(\(variant)...)"
    return memoize(desc, (
      kind: .variantMember(variant: variant),
      frees: variant.type.frees,
      vars: variant.type.vars))
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
    if case .free = self.kind {
      assert(childFrees.isEmpty)
      return [self]
    }
    return childFrees
  }

  var vars: Set<Type> {
    if case .var_ = self.kind {
      assert(childVars.isEmpty)
      return [self]
    }
    return childVars
  }

  var isResolved: Bool {
    switch self.kind {
    case .free: return false
    default: return childFrees.isEmpty
    }
  }

  var isConstraintEligible: Bool {
    // For a type to appear in a constraint, it must either be completely reified already,
    // or else be a free type that points into the mutable types array of the TypeCtx.
    switch self.kind {
    case .free: return true
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


  func reify(_ argFields: [TypeField]) -> Type {
    switch self.kind {
    case .free, .host, .prim: return self
    case .all(let members): return .All(reify(argFields, members: members))
    case .any(let members): return .Any_(reify(argFields, members: members))
    case .poly(let members): return .Poly(reify(argFields, members: members))
    case .sig(let dom, let ret):
      return .Sig(dom: dom.reify(argFields), ret: ret.reify(argFields))
    case .struct_(let fields, let variants):
      return .Struct(fields: reify(argFields, fields: fields), variants: reify(argFields, fields: variants))
    case .var_(let name):
      for field in argFields {
        if field.label == name {
          return field.type
        }
      }
      return self
    case .variantMember(let variant):
      return .VariantMember(variant: variant.substitute(type: variant.type.reify(argFields)))
    }
  }

  func reify(_ argFields: [TypeField], members: Set<Type>) -> Set<Type> {
    return Set(members.map { $0.reify(argFields) })
  }

  func reify(_ argFields: [TypeField], fields: [TypeField]) -> [TypeField] {
    return fields.map { $0.substitute(type: $0.type.reify(argFields)) }
  }
}



let typeEmpty = Type.Any_([]) // aka "Bottom type"; the empty set.
let typeEvery = Type.All([]) // aka "Top type"; the set of all objects.
let typeVoid = Type.Struct(fields: [], variants: [])

let typeBool      = Type.Prim("Bool")
let typeInt       = Type.Prim("Int")
let typeNamespace = Type.Prim("Namespace")
let typeNever     = Type.Prim("Never")
let typeStr       = Type.Prim("Str")
let typeType      = Type.Prim("Type")

let intrinsicTypes = [
  typeBool,
  typeEmpty,
  typeEvery,
  typeInt,
  typeNamespace,
  typeNever,
  typeStr,
  typeType,
]
