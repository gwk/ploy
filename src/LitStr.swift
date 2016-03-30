// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitStr: _Form, Expr { // string literal: `'hi', "hi"`.
  let val: String

  init(_ syn: Syn, val: String) {
    self.val = val
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, ": \(val)\n") // TODO: escape val properly.
  }

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = typeStr
    ctx.trackExpr(self, type: type)
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
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
  }
}


