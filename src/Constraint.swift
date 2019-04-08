// © 2016 George King. Permission to use this file is granted in license.txt.


enum Constraint: CustomStringConvertible, Encodable {

  enum CodingKeys: CodingKey {
    case prop
    case rel
    //case sel
  }

  // A type constraint to be resolved during type checking.
  // Constraints contain types and the expressions from which they were generated for error reporting.

  case prop(PropCon) // property constraint between an accessee type and an accessed type via an accessor.
  case rel(RelCon) // relation constraint between actual and expected types.
  //case sel(SelCon) // Method selection constraint between a polyfn reference and an expected type.

  var description: String {
    switch self {
    case .prop(let prop): return String(describing: prop)
    case .rel(let rel): return String(describing: rel)
    //case .sel(let sel): return String(describing: sel)
    }
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .prop(let prop): try c.encode(prop, forKey: .prop)
    case .rel(let rel): try c.encode(rel, forKey: .rel)
    //case .sel(let sel): try c.encode(sel, forKey: .sel)
    }
  }
}


struct PropCon: Encodable {
  // A property access constraint.
  // This specialization is required to represent the expectation that the property named by the acessor exists in the accessee.

  struct Err: Error {
    let prop: PropCon
    let msg: String
  }

  enum CodingKeys: CodingKey {
    case loc
    case accesseeType
    case accType
  }

  let acc: Acc
  let accesseeType: Type
  let accType: Type

  init(acc: Acc, accesseeType: Type, accType: Type) {
    self.acc = acc
    self.accesseeType = accesseeType
    self.accType = accType
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(loc, forKey: .loc)
    try c.encode(accesseeType, forKey: .accesseeType)
    try c.encode(accType, forKey: .accType)
  }

  var loc: String { return self.acc.syn.description }

  func error(_ msg: String) -> Err {
    return Err(prop: self, msg: msg)
  }
}


struct RelCon: CustomStringConvertible, Encodable {
  // A generic binary relation constraint, consisting of 'actual' and 'expected' sides.

  struct Err: Error, CustomStringConvertible, Encodable {
    typealias MsgThunk = (String, String) -> String
    let rel: RelCon
    let msgThunk: MsgThunk
    var description: String { return "Err(rel: `\(rel)`; msg: `\(msgThunk(rel.act.role.desc, rel.exp.role.desc))`)" }

    func encode(to encoder: Encoder) throws { try encoder.encodeDescription(self) }
  }

  let act: Side
  let exp: Side
  let desc: String

  var description: String { return "\(act); \(exp); desc: \(desc)" }

  func error(_ msgThunk: @escaping (String, String) -> String) -> Err { return Err(rel: self, msgThunk: msgThunk) }
}


struct Side: CustomStringConvertible, Encodable {

  enum Role: Encodable {
    case act
    case arg
    case exp
    case poly
    case dom
    case ret

    var desc: String {
      switch self {
      case .act: return "actual"
      case .arg: return "argument"
      case .exp: return "expected"
      case .poly: return "polyfunction"
      case .dom: return "domain"
      case .ret: return "return"
      }
    }

    func encode(to encoder: Encoder) throws { try encoder.encodeDescription(self) }
  }

  enum CodingKeys: CodingKey {
    case loc
    case role
    case type
    case chainDesc
  }

  let role: Role
  let expr: Expr // the literal expression associated with the constraint; may be a parent.
  let type: Type
  let chain: Chain<String> // describes the path into the parent literal expression.

  init(_ role: Role, expr: Expr, type: Type, chain: Chain<String> = .end) {
    self.role = role
    self.expr = expr
    self.type = type
    self.chain = chain
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(expr.syn.description, forKey: .loc)
    try c.encode(role, forKey: .role)
    try c.encode(type, forKey: .type)
    try c.encode(chainDesc, forKey: .chainDesc)
  }

  var description: String { return "\(role.desc): \(chainDesc)\(expr): \(type)" }

  var chainDesc: String { return chain.map({"\($0) of "}).joined() }

  func sub(_ role: Role, expr: Expr?, type: Type, desc: String) -> Side {
    if let expr = expr {
      return Side(role, expr: expr, type: type)
    } else {
      return Side(role, expr: self.expr, type: type, chain: .link(desc, chain))
    }
  }

  var isLit: Bool {
    switch chain {
    case .link: return false
    case .end: return true
    }
  }

  var litExpr: Expr? {
    switch chain {
    case .link: return nil
    case .end: return expr
    }
  }
}
