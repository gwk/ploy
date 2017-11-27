// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable, Comparable {

  enum Kind {
    case all(members: [Type])
    case any(members: [Type])
    case free(index: Int)
    case host
    case poly(members: [Type])
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

  class func All(_ members: [Type]) throws -> Type {
    assert(members.isSorted, "members: \(members)")
    let merged = try computeIntersect(types: members)
    let desc = merged.isEmpty ? "Every" : "All<\(merged.descriptions.sorted().joined(separator: " "))>"
    return memoize(desc, (
      kind: .all(members: merged),
      frees: Set(merged.flatMap { $0.frees }),
      vars: Set(merged.flatMap { $0.vars })))
  }

  class func Any_(_ members: [Type]) throws -> Type {
    assert(members.isSorted, "members: \(members)")
    let merged = try computeUnion(types: members)
    let desc = merged.isEmpty ? "Never" : "Any<\(merged.descriptions.sorted().joined(separator: " "))>"
    return memoize(desc, (
      kind: .any(members: merged),
      frees: Set(merged.flatMap { $0.frees }),
      vars: Set(merged.flatMap { $0.vars })))
  }

  class func Free(_ index: Int) -> Type { // should only be called by addFreeType.
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

  class func Poly(_ members: [Type]) -> Type {
    assert(members.isSorted, "members: \(members)")
    // TODO: assert disjoint.
    let desc = "Poly<\(members.descriptions.sorted().joined(separator: " "))>"
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
    let descs = members.descriptions.joined(separator: " ")
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


  class func computeIntersect(types: [Type]) throws -> [Type] {
    var merged: [Type] = []
    for type in types {
      switch type.kind {
      case .all(let members): merged.append(contentsOf: members)
      case .any: throw "type intersection contains union member: `\(type)`"
      case .poly: throw "type intersection contains poly member: `\(type)`"
      default: throw "type intersection not yet implemented." // merged.append(type)
      }
    }
    merged.sort()
    return merged
  }


  class func computeUnion(types: [Type]) throws -> [Type] {
    var merged: [Type] = []
    for type in types {
      switch type.kind {
      case .any(let members): merged.append(contentsOf: members)
      case .poly: throw "type union contains poly member: `\(type)`"
      default: merged.append(type)
      }
    }
    merged.sort()
    return merged
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

  var varName: String {
    if case .var_(let name) = kind { return name }
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

  var varNames: Set<String> {
    return Set(vars.map { $0.varName })
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

  var isConcrete: Bool {
    switch self.kind {
    case .var_: return false
    default: return childVars.isEmpty
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

  func reify(_ substitutions: [String:Type]) -> Type {
    // Recursive helper assumes that the substitution makes sense.
    // TODO: optimize by checking self.vars.isEmpty?
    switch self.kind {
    case .free, .host, .prim: return self
    case .all(let members): return try! .All(reify(substitutions, members: members))
    case .any(let members): return try! .Any_(reify(substitutions, members: members))
    case .poly(let members): return .Poly(reify(substitutions, members: members))
    case .sig(let dom, let ret):
      return .Sig(dom: dom.reify(substitutions), ret: ret.reify(substitutions))
    case .struct_(let fields, let variants):
      return .Struct(fields: reify(substitutions, fields: fields), variants: reify(substitutions, fields: variants))
    case .var_(let name):
      for (n, type) in substitutions {
        if n == name {
          return type
        }
      }
      return self
    case .variantMember(let variant):
      return .VariantMember(variant: variant.substitute(type: variant.type.reify(substitutions)))
    }
  }

  func reify(_ substitutions: [String:Type], members: [Type]) -> [Type] {
    return members.sortedMap{ $0.reify(substitutions) }
  }

  func reify(_ substitutions: [String:Type], fields: [TypeField]) -> [TypeField] {
    return fields.map { $0.substitute(type: $0.type.reify(substitutions)) }
  }
}



let typeNever = try! Type.Any_([]) // aka "Bottom type"; the type with no values.
let typeEvery = try! Type.All([]) // aka "Top type"; the set of all objects.
let typeNull = Type.Struct(fields: [], variants: []) // aka "nil", "Unit type"; the empty struct.

let typeBool      = Type.Prim("Bool")
let typeInt       = Type.Prim("Int")
let typeNamespace = Type.Prim("Namespace")
let typeStr       = Type.Prim("Str")
let typeType      = Type.Prim("Type")
let typeVoid      = Type.Prim("Void") // Note: Void is distinct from Never.

let intrinsicTypes = [
  typeBool,
  typeEvery,
  typeInt,
  typeNamespace,
  typeNever,
  typeStr,
  typeType,
  typeVoid,
]
