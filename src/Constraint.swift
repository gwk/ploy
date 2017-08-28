// © 2016 George King. Permission to use this file is granted in license.txt.


enum Constraint: CustomStringConvertible {

  // A type constraint to be resolved during type checking.
  // Constraints contain types and the expressions from which they were generated for error reporting.

  case prop(PropCon) // property constraint between an accessee type and an accessed type via an accessor.
  case rel(RelCon) // relation constraint between actual and expected types.

  var description: String {
    switch self {
    case .prop(let prop): return String(describing: prop)
    case .rel(let rel): return String(describing: rel)
    }
  }
}


struct PropCon {
  // A property access constraint.
  // This specialization is required to represent the expectation that the property named by the acessor exists in the accessee.

  struct Err: Error {
    let prop: PropCon
    let msg: String
  }

  let acc: Acc
  let accesseeType: Type
  let accType: Type

  init(acc: Acc, accesseeType: Type, accType: Type) {
    assert(accesseeType.isConstraintEligible)
    assert(accType.isConstraintEligible)
    self.acc = acc
    self.accesseeType = accesseeType
    self.accType = accType
  }

  func error(_ msg: String) -> Err {
    return Err(prop: self, msg: msg)
  }
}


struct RelCon {
  // A generic binary relation constraint, consisting of 'actual' and 'expected' sides.

  struct Err: Error {
    let rel: RelCon
    let msgThunk: ()->String
  }

  let act: Side
  let exp: Side
  let desc: String

  func error(_ msgThunk: @escaping @autoclosure ()->String) -> Err {
    return Err(rel: self, msgThunk: msgThunk)
  }
}


struct Side: CustomStringConvertible {

  let expr: Expr // the literal expression associated with the constraint; may be a parent.
  let type: Type
  let chain: Chain<String> // describes the path into the parent literal expression.

  init(expr: Expr, type: Type, chain: Chain<String> = .end) {
    assert(type.isConstraintEligible)
    self.expr = expr
    self.type = type
    self.chain = chain
  }

  var description: String { return "\(expr): \(type)" }
  func sub(expr: Expr?, type: Type, desc: String) -> Side {
    if let expr = expr {
      return Side(expr: expr, type: type)
    } else {
      return Side(expr: self.expr, type: type, chain: .link(desc, chain))
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
    case.link: return nil
    case .end: return expr
    }
  }
}
