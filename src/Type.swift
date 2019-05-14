// © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Type: CustomStringConvertible, Hashable, Comparable, Encodable {

  enum Kind: Equatable {
    case free(index: Int)
    case host
    case intersect(members: [Type])
    case poly(members: [Type])
    case prim
    case refinement(base: Type, pred: Expr)
    case sig(dom: Type, ret: Type)
    case struct_(posFields:[Type], labFields: [TypeLabField], variants: [TypeVariant])
    case union(members: [Type])
    case req(base: Type, requirement: Type)
    case var_(name: String)
    case variantMember(variant: TypeVariant)

    var precedence: Int {
      switch self {
      case .poly: return 0
      case .union: return 1
      case .intersect: return 2
      case .sig: return 3
      case .refinement: return 4
      case .req: return 4
      default: return 5
      }
    }

    var separator: String {
      switch self {
      case .poly: return " + "
      case .union: return  "|"
      case .intersect: return "&"
      case .sig: return "%"
      case .refinement: return ":?"
      case .req: return "::"
      default: fatal(self)
      }
    }
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

  func parenthesizedDesc(_ precedence: Int) -> String {
    if precedence < self.kind.precedence { return description }
    else { return "(\(description))" }
  }

  class func memoize(_ description: String, kind: Kind, _ parts: @autoclosure ()->(frees: Set<Type>, vars: Set<Type>)) -> Type {
    if let memo = allTypes[description] { return memo }
    let (frees, vars) = parts()
    let type = Type(description, kind: kind, frees: frees, vars: vars)
    allTypes[description] = type
    return type
  }

  class func memoize(kind: Kind, members: [Type], emptyDesc: String = "") -> Type {
    let description = members.isEmpty ? emptyDesc : binaryDesc(kind, members)
    if description.isEmpty { fatalError("empty type description: \(kind)") }
    return memoize(description, kind: kind, (
      frees: Set(members.flatMap { $0.frees }),
      vars: Set(members.flatMap { $0.vars })))
  }

  class func binaryDesc(_ kind: Kind, _ members: [Type]) -> String {
    let elDescs = members.map { $0.parenthesizedDesc(kind.precedence) }
    let separator = kind.separator
    if elDescs.count == 1 { return separator.strip(char: " ") + elDescs[0] }
    return elDescs.joined(separator: separator)
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
    let members = try computeIntersect(types: members)
    if members.count == 1 { return members[0] }
    let kind = Kind.intersect(members: members)
    return memoize(kind: kind, members: members)
  }

  class func Poly(_ members: [Type]) -> Type {
    assert(members.isSortedStrict, "members: \(members)")
    // TODO: assert disjoint.
    let kind = Kind.poly(members: members)
    return memoize(kind: kind, members: members, emptyDesc: "EmptyPoly")
  }

  fileprivate class func Prim(_ name: String) -> Type {
    return Type(name, kind: .prim)
  }

  class func Refinement(base: Type, pred: Expr) -> Type {
    let desc = "\(base):?\(pred)" // TODO: figure out how to represent the predicate globally.
    let t = memoize(desc, kind: .refinement(base: base, pred: pred), (
      frees: base.frees,
      vars: base.vars))
    fatalError("refinement types not yet supported: \(t)")
  }

  class func Req(base: Type, requirement: Type) -> Type {
    return memoize(kind: .req(base: base, requirement: requirement), members: [base, requirement])
  }

  class func Sig(dom: Type, ret: Type) -> Type {
    return memoize(kind: .sig(dom: dom, ret: ret), members: [dom, ret])
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
    return memoize(desc, kind: .struct_(posFields: posFields, labFields: labFields, variants: variants), (
      frees: Set(memberTypes.flatMap { $0.frees }),
      vars:  Set(memberTypes.flatMap { $0.vars })))
  }

  class func Union(_ members: [Type]) throws -> Type {
    let members = try computeUnion(types: members)
    if members.count == 1 { return members[0] }
    return memoize(kind: .union(members: members), members: members, emptyDesc: "Empty")
  }

  class func Var(name: String) -> Type {
    let desc = "^\(name)"
    return memoize(desc, kind: .var_(name: name), (
      frees: [],
      vars: []))
  }

  class func Variant(label: String, type: Type) -> Type {
    return Struct(posFields: [], labFields: [], variants: [TypeVariant(label: label, type: type)])
  }

  class func VariantMember(variant: TypeVariant) -> Type {
    let desc = "(\(variant)...)"
    return memoize(desc, kind: .variantMember(variant: variant), (
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
    fatal(self)
  }

  var varName: String {
    if case .var_(let name) = kind { return name }
    fatal(self)
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


  var polyDomRet: (Type, Type) {
    guard case .poly(let members) = self.kind else { fatal(self) }
    var doms = [Type]()
    var rets = [Type]()
    for member in members {
      let (dom, ret) = member.sigDomRet
      doms.append(dom)
      rets.append(ret)
    }
    let dom = try! Type.Union(doms.sorted())
    let ret = try! Type.Union(rets.sorted())
    return (dom, ret)
  }


  var sigDom: Type {
    switch self.kind {
    case .sig(let dom, _): return dom
    default: fatal(label: "non-sig type", self)
    }
  }

  var sigRet: Type {
    switch self.kind {
    case .sig(_, let ret): return ret
    default: fatal(label: "non-sig type", self)
    }
  }

  var sigDomRet: (Type, Type) {
    switch self.kind {
    case .sig(let domRet): return domRet
    default: fatal(label: "non-sig type", self)
    }
  }


  func transformLeaves(_ fn: (Type)->Type) -> Type {
    switch self.kind {
    case .free, .host, .prim, .var_: return fn(self)
    case .intersect(let members): return try! .Intersect(members.sortedMap{$0.transformLeaves(fn)})
    case .poly(let members): return .Poly(members.sortedMap{$0.transformLeaves(fn)})
    case .refinement(let base, let pred): return .Refinement(base: base.transformLeaves(fn), pred: pred)
    case .req(let base, let requirement):
      return .Req(base: base.transformLeaves(fn), requirement: requirement.transformLeaves(fn))
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
      case .var_(let name):
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
