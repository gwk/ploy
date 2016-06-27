// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitStr: _Form, Expr { // string literal: `'hi', "hi"`.
  let val: String

  init(_ syn: Syn, val: String) {
    self.val = val
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": \"\(val)\"\n") // TODO: use source string.
  }

  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = typeStr
    ctx.trackExpr(self, type: type)
    return type
  }

  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    var s = "\""
    for code in val.codes {
      switch code {
      case "\0":    s.append("\\0")
      case "\u{8}": s.append("\\b")
      case "\t":    s.append("\\t")
      case "\n":    s.append("\\n")
      case "\r":    s.append("\\r")
      case "\"":    s.append("\\\"")
      case "\\":    s.append("\\\\")
      default:
        if code < " " || code > "~" {
          s.append("\\u{\(Int(code.value).hex)}")
        } else {
          s.append(Character(code))
        }
      }
    }
    s.append(Character("\""))
    em.str(depth, s)
  }
}


