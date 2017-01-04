// © 2016 George King. Permission to use this file is granted in license.txt.


struct Constraint {

  struct Side {
    let expr: Expr // the literal expression associated with the constraint; may be a parent.
    let type: Type
    let chain: Chain<String> // describes the path into the parent literal expression.

    init(expr: Expr, type: Type, chain: Chain<String> = .end) {
      self.expr = expr
      self.type = type
      self.chain = chain
    }

    var isSub: Bool {
      switch chain {
      case .link: return true
      case .end: return false
      }
    }
  }

  let act: Side
  let exp: Side
  let desc: String
}


