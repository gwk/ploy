// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitStr: _Form, Expr { // string literal: `'hi', "hi"`.
  let val: String

  init(_ syn: Syn, val: String) {
    self.val = val
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(" \"")
    target.write(val) // TODO: escape properly.
    target.write("\"\n")
  }
  
  func compileExpr(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope, _ expType: Type, isTail: Bool) -> Type {
    let em = scope.em
    refine(ctx, exp: expType, act: typeStr)
    var s = "\""
    for code in val.codes {
      switch code {
      case "\0":    s.appendContentsOf("\\0")
      case "\u{8}": s.appendContentsOf("\\b")
      case "\t":    s.appendContentsOf("\\t")
      case "\n":    s.appendContentsOf("\\n")
      case "\r":    s.appendContentsOf("\\r")
      case "\"":    s.appendContentsOf("\\\"")
      case "\\":    s.appendContentsOf("\\\\")
      default:
        if code < " " || code > "~" {
          s.appendContentsOf("\\u{\(Int(code.value).hex)}")
        } else {
          s.append(Character(code))
        }
      }
    }
    s.append(Character("\""))
    em.str(depth, isTail ? "{v:\(s)}" : s)
    return typeStr
  }
}


