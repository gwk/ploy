// © 2016 George King. Permission to use this file is granted in license.txt.


enum Constraint {
  case rel(Rel)
}


struct Rel {
  let act: Side
  let exp: Side
  let desc: String
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

  var isSub: Bool {
    switch chain {
    case .link: return true
    case .end: return false
    }
  }

  var litExpr: Expr? {
    switch chain {
    case.link: return nil
    case .end: return expr
    }
  }
}
