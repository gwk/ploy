// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable, Comparable, Encodable {

  enum Kind {
    case free(index: Int)
    case host
    case intersect(members: [Type])
    case method(members: [Type], dom:Type, ret:Type)
    case poly(members: [Type])
    case prim
    case refinement(base: Type, pred: Expr)
    case sig(dom: Type, ret: Type)
    case struct_(posFields:[Type], labFields: [TypeLabField], variants: [TypeVariant])
    case union(members: [Type])
    case var_(name: String, requirement: Type)
    case variantMember(variant: TypeVariant)
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

  class func Free(_ index: Int) -> Type { // should only be called by addFreeType and copyForParent.
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

  class func Intersect(_ members: [Type]) throws -> Type {
    let merged = try computeIntersect(types: members)
    if merged.isEmpty { fatalError("empty intersection") }
    if merged.count == 1 { return merged[0] }
    let desc = "(\(merged.descriptions.joined(separator: "&")))"
    return memoize(desc, (
      kind: .intersect(members: merged),
      frees: Set(merged.flatMap { $0.frees }),
      vars: Set(merged.flatMap { $0.vars })))
  }

  class func Method(_ members: [Type]) throws -> Type {
    assert(members.isSortedStrict, "members: \(members)")
    // TODO: assert disjoint.
    if members.count == 1 { return members[0] }
    var doms = [Type]()
    var rets = [Type]()
    for member in members {
      let (dom, ret) = member.sigDomRet
      doms.append(dom)
      rets.append(ret)
    }
    let dom = try Union(doms.sorted())
    let ret = try Union(rets.sorted())
    let contents = members.descriptions.joined(separator: " + ")
    let desc = "(\(contents))"
    return memoize(desc, (
      kind: .method(members: members, dom: dom, ret: ret),
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func Poly(_ members: [Type]) -> Type {
    assert(members.isSortedStrict, "members: \(members)")
    // TODO: assert disjoint.
    let desc = "Poly<\(members.descriptions.joined(separator: " "))>"
    return memoize(desc, (
      kind: .poly(members: members),
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  fileprivate class func Prim(_ name: String) -> Type {
    return Type(name, kind: .prim)
  }

  class func Refinement(base: Type, pred: Expr) -> Type {
    let desc = "\(base):?\(pred)" // TODO: figure out how to represent the predicate globally.
    let t = memoize(desc, (
      kind: .refinement(base: base, pred: pred),
      frees: base.frees,
      vars: base.vars))
    fatalError("refinement types not yet supported: \(t)")
  }

  class func Sig(dom: Type, ret: Type) -> Type {
    let desc = "\(dom.nestedSigDescription)%\(ret.nestedSigDescription)"
    return memoize(desc, (
      kind: .sig(dom: dom, ret: ret),
      frees: dom.frees.union(ret.frees),
      vars: dom.vars.union(ret.vars)))
  }

  class func Struct(posFields: [Type], labFields: [TypeLabField], variants: [TypeVariant]) -> Type {
    var descs = Array(posFields.descriptions)
    descs.append(contentsOf: labFields.descriptions)
    descs.append(contentsOf: variants.descriptions)
    let desc_j = descs.descriptions.joined(separator: " ")
    let desc = "(\(desc_j))"
    var memberTypes = posFields
    memberTypes.append(contentsOf: labFields.map{$0.type})
    memberTypes.append(contentsOf: variants.map{$0.type})
    return memoize(desc, (
      kind: .struct_(posFields: posFields, labFields: labFields, variants: variants),
      frees: Set(memberTypes.flatMap { $0.frees }),
      vars:  Set(memberTypes.flatMap { $0.vars })))
  }

  class func Union(_ members: [Type]) throws -> Type {
    let merged = try computeUnion(types: members)
    if merged.count == 1 { return merged[0] }
    let desc = merged.isEmpty ? "Empty" : "(\(merged.descriptions.joined(separator: "|")))"
    return memoize(desc, (
      kind: .union(members: merged),
      frees: Set(merged.flatMap { $0.frees }),
      vars: Set(merged.flatMap { $0.vars })))
  }

  class func Var(name: String, requirement: Type) -> Type {
    let reqDesc = String(describing: requirement)
    let desc = "(\(name)::\(reqDesc))"
    return memoize(desc, (
      kind: .var_(name: name, requirement: requirement),
      frees: requirement.frees,
      vars: requirement.vars))
  }

  class func Variant(label: String, type: Type) -> Type {
    return Struct(posFields: [], labFields: [], variants: [TypeVariant(label: label, type: type)])
  }

  class func VariantMember(variant: TypeVariant) -> Type {
    let desc = "(\(variant)...)"
    return memoize(desc, (
      kind: .variantMember(variant: variant),
      frees: variant.type.frees,
      vars: variant.type.vars))
  }


  class func computeIntersect(types: [Type]) throws -> [Type] {
    var merged: Set<Type> = []
    for type in types {
      switch type.kind {
      case .intersect(let members): merged.insert(contentsOf: members)
      case .union: throw "type intersection contains union member: `\(type)`"
      case .poly: throw "type intersection contains poly member: `\(type)`"
      default: merged.insert(type)
      }
    }
    return merged.sorted()
  }


  class func computeUnion(types: [Type]) throws -> [Type] {
    var merged: Set<Type> = []
    for type in types {
      switch type.kind {
      case .union(let members): merged.insert(contentsOf: members)
      case .poly: throw "type union contains poly member: `\(type)`"
      default: merged.insert(type)
      }
    }
    return merged.sorted()
  }


  var nestedSigDescription: String {
    switch kind {
    case .sig: return "(\(description))"
    default: return description
    }
  }

  func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

  var freeIndex: Int {
    if case .free(let index) = kind { return index }
    fatalError()
  }

  var varName: String {
    if case .var_(let name, _) = kind { return name }
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

  var isConcrete: Bool {
    switch self.kind {
    case .var_: return false
    default: return childVars.isEmpty
    }
  }

  static func ==(l: Type, r: Type) -> Bool { return l === r }

  static func <(l: Type, r: Type) -> Bool { return l.description < r.description }

  func encode(to encoder: Encoder) throws { try encoder.encodeDescription(self) }


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

  var sigDomRet: (Type, Type) {
    switch self.kind {
    case .sig(let domRet): return domRet
    default: fatalError()
    }
  }


  func transformLeaves(_ fn: (Type)->Type) -> Type {
    switch self.kind {
    case .free, .host, .prim, .var_: return fn(self)
    case .intersect(let members): return try! .Intersect(members.sortedMap{$0.transformLeaves(fn)})
    case .poly(let members): return .Poly(members.sortedMap{$0.transformLeaves(fn)})
    case .method(let members, _, _): return try! .Method(members.sortedMap{$0.transformLeaves(fn)})
    case .refinement(let base, let pred): return .Refinement(base: base.transformLeaves(fn), pred: pred)
    case .sig(let dom, let ret): return .Sig(dom: dom.transformLeaves(fn), ret: ret.transformLeaves(fn))
    case .struct_(let posFields, let labFields, let variants):
      return .Struct(
        posFields: posFields.map(fn),
        labFields: labFields.map{$0.transformType(fn)},
        variants: variants.map{$0.transformType(fn)})
    case .union(let members): return try! .Union(members.sortedMap{$0.transformLeaves(fn)})
    case .variantMember(let variant): return .VariantMember(variant: variant.transformType(fn))
    }
  }


  func substitute(_ substitutions: [String:Type]) -> Type {
    // Recursive helper assumes that the substitution makes sense.
    // TODO: optimize by checking self.vars.isEmpty?
    return transformLeaves { type in
      switch type.kind {
      case .var_(let name, let requirement):
        for (n, sub) in substitutions {
          if n == name {
            return sub
          }
        }
        return type
      default: return type
      }
    }
  }
}


let typeNull = Type.Struct(posFields: [], labFields: [], variants: []) // aka "nil", "Unit type"; the empty struct.
let typeEmpty = try! Type.Union([]) // AKA "Bottom type"; the type with no values.

let typeAny       = Type.Prim("Any") // AKA "Top type"; the set of all values.
let typeBool      = Type.Prim("Bool")
let typeInt       = Type.Prim("Int")
let typeNamespace = Type.Prim("Namespace")
let typeNever     = Type.Prim("Never") // The type for functions that never return.
let typeStr       = Type.Prim("Str")
let typeType      = Type.Prim("Type")
let typeVoid      = Type.Prim("Void") // The quasi-value for statements and functions that return nothing.

let intrinsicTypes = [
  typeAny,
  typeBool,
  typeInt,
  typeNamespace,
  typeNever,
  typeStr,
  typeType,
  typeVoid,
]
