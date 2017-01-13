// © 2016 George King. Permission to use this file is granted in license.txt.


enum Constraint: CustomStringConvertible {
  case rel(Rel)
  case prop(Prop)

  var description: String {
    switch self {
    case .rel(let rel): return String(describing: rel)
    case .prop(let prop): return String(describing: prop)
    }
  }
}


struct Rel {

  struct Err: Error {
    let rel: Rel
    let msgThunk: ()->String
  }

  let act: Side
  let exp: Side
  let desc: String

  func error(_ msgThunk: @escaping @autoclosure ()->String) -> Err {
    return Err(rel: self, msgThunk: msgThunk)
  }
}


struct Prop {

  struct Err: Error {
    let prop: Prop
    let msg: String
  }

  let acc: Acc
  let accesseeType: Type
  let accType: Type

  func error(_ msg: String) -> Err {
    return Err(prop: self, msg: msg)
  }
}


struct Side {

  let expr: Expr // the literal expression associated with the constraint; may be a parent.
  let type: Type
  let chain: Chain<String> // describes the path into the parent literal expression.

  init(expr: Expr, type: Type, chain: Chain<String> = .end) {
    self.expr = expr
    self.type = type
    self.chain = chain
  }

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
