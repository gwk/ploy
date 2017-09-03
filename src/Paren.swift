// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Paren: Form {
  // parenthesized expression: `(a)` or `(a b)`.
  // A single parenthesized expression is a purely syntactic form, with "scalar" type.
  // Multiple expressions within parentheses create a compound (either struct or enum).
  let els: [Expr]

  init(_ syn: Syn, els: [Expr]) {
    self.els = els
    super.init(syn)
  }

  override var textTreeChildren: [Any] { return els }

  // MARK: Paren

  var isScalarValue: Bool {
    return els.count == 1 && els[0].argLabel == nil
  }

  var isScalarType: Bool {
    return els.count == 1 && els[0].parLabel == nil
  }

  var fieldEls: [Expr] {
    return els.filter { !$0.isTagged }
  }

  var variantEls: [Expr] {
    return els.filter { $0.isTagged }
  }
}
