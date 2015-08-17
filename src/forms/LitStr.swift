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
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    var s = "\""
    for code in val.codes {
      switch code {
      case "\0":    s.extend("\\0")
      case "\u{8}": s.extend("\\b")
      case "\t":    s.extend("\\t")
      case "\n":    s.extend("\\n")
      case "\r":    s.extend("\\r")
      case "\"":    s.extend("\\\"")
      case "\\":    s.extend("\\\\")
      default:
        if code < " " || code > "~" {
          s.extend("\\u{\(Int(code.value).hex)}")
        } else {
          s.append(Character(code))
        }
      }
    }
    s.append(Character("\""))
    em.str(depth, s)
    return typeStr
  }
}


