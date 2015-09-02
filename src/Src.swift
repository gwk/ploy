// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


let ployOctChars = Set("01234567".characters)
let ployDecChars = Set("0123456789".characters)
let ployHexChars = Set("0123456789ABCDEFabcdef".characters)
let ploySymHeadChars = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".characters)
let ploySymTailChars = ploySymHeadChars.union(ployDecChars).union(["-"])
let ployTerminatorChars = Set(")>]};".characters)


class Src: CustomStringConvertible {
  let path: String
  let text: String
  
  init(path: String) {
    self.path = path
    self.text = InFile(path: path).read()
  }
  
  init(name: String) {
    self.path = name
    self.text = ""
  }
  
  var description: String { return "Src(\(path))" }
  
  var chars: String.CharacterView { return text.characters }
  
  var startPos: Pos { return Pos(idx: text.characters.startIndex, line: 0, col: 0) }
  
  func adv(pos: Pos, count: Int = 1) -> Pos {
    var idx = pos.idx
    var c = count
    while c > 0 && idx < chars.endIndex {
      idx = idx.successor()
      c--
    }
    return Pos(idx: idx, line: pos.line, col: pos.col + count)
  }
  
  func advLine(pos: Pos) -> Pos {
    assert(pos.idx < chars.endIndex)
    let idx = pos.idx.successor()
    return Pos(idx: idx, line: pos.line + 1, col: 0)
  }
  
  func hasSome(pos: Pos) -> Bool { return pos.idx < chars.endIndex }
  
  func hasString(pos: Pos, _ string: String) -> Bool { return chars.has(string.characters, atIndex: pos.idx) }
  
  func char(pos: Pos) -> Character { return text[pos.idx] }
  
  func slice(pos: Pos, _ end: Pos) -> String { return text[pos.idx..<end.idx] }
  
  /// returns the line of source text containing pos; always excludes newline for consistency.
  func line(pos: Pos) -> String {
    var s = pos.idx
    while s > chars.startIndex {
      let i = s.predecessor()
      if text[i] == "\n" { break }
      s = i
    }
    var e = pos.idx
    while e < chars.endIndex {
      if text[e] == "\n" { break }
      e = e.successor()
    }
    return text[s..<e]
  }

  func underline(pos: Pos, _ end: Pos? = nil) -> String {
    let indent = String(count: pos.col, repeatedValue: Character(" "))
    if let end = end {
      assert(pos.line == end.line)
      if pos.idx < end.idx {
        return indent + String(count: end.col - pos.col, repeatedValue: Character("~"))
      }
    }
    return indent + "^"
  }
  
  func underlines(pos: Pos, _ end: Pos, lineLen: Int) -> (String, String) {
    assert(pos.line < end.line)
    let spaces = String(count: pos.col, char: " ")
    let squigs = String(count: lineLen - pos.col, char: "~")
    return ("\(spaces)\(squigs)-", String(count: end.col, char: "~"))
  }

  func errPos(pos: Pos, end: Pos?, prefix: String, msg: String) {
    let posLine = line(pos)
    err("\(prefix): \(path):\(pos.line + 1):")
    if let end = end {
      if pos.line == end.line { // single line.
        if pos.col < end.col { // multiple columns.
          err("\(pos.col + 1)-\(end.col): \(msg)\n  \(posLine)\n  \(underline(pos, end))\n")
          return
        }
      } else { // multiline.
        let endLine = line(end)
        let (underlinePos, underlineEnd) = underlines(pos, end, lineLen: posLine.characters.count)
        err("\(pos.col + 1):\n  \(posLine)\n  \(underlinePos)\n")
        err("to: \(path):\(end.line + 1):\(end.col): \(msg)\n  \(endLine)\n  \(underlineEnd)\n")
        return
      }
    }
    // single line, single column.
    err("\(pos.col + 1): \(msg)\n  \(posLine)\n  \(underline(pos))\n")
  }

  @noreturn func fail(pos: Pos, _ end: Pos?, _ prefix: String, _ msg: String) {
    errPos(pos, end: end, prefix: prefix, msg: msg)
    Process.exit(1)
  }

  @noreturn func failParse(pos: Pos, _ end: Pos?, _ msg: String) { fail(pos, end, "parse error", msg) }

  func parseSpace(pos: Pos) -> Pos {
    var p = pos
    var inComment = false
    loop: while hasSome(p) {
      switch char(p) {
      case "\n":
        p = advLine(p)
        inComment = false
      case " ":
        p = adv(p)
      case "#":
        p = adv(p)
        inComment = true
      default:
        if inComment {
          p = adv(p)
        } else {
          break loop
        }
      }
    }
    return p
  }
  
  // MARK: leaves.
  
  func parseSym(pos: Pos) -> Sym {
    assert(ploySymHeadChars.contains(char(pos)))
    var prev = char(pos)
    var p = adv(pos)
    while hasSome(p) {
      let c = char(p)
      if !ploySymTailChars.contains(c) { break }
      if prev == "-" && c == "-" {
        failParse(p, nil, "symbols cannot contain repeated '-' characters.")
      }
      prev = c
      p = adv(p)
    }
    return Sym(Syn(src: self, pos: pos, visEnd: p, end: parseSpace(p)), name: slice(pos, p))
  }
  
  func parseLitNum(pos: Pos, var foundDot: Bool = false) -> LitNum {
    assert(ployDecChars.contains(char(pos)) || char(pos) == ".")
    var p = adv(pos)
    while hasSome(p) {
      let c = char(p)
      if c == "." {
        if foundDot {
          failParse(pos, adv(p), "repeated '.' in number literal.")
        }
        foundDot = true
      } else if !ployDecChars.contains(c) {
        break
      }
      p = adv(p)
    }
    let string = slice(pos, p)
    if foundDot {
      failParse(pos, p, "floating point literals are not yet supported.")
    }
    guard let val = Int(string, radix: 10) else {
      failParse(pos, p, "invalid number literal (INTERNAL ERROR).")
    }
    return LitNum(Syn(src: self, pos: pos, visEnd: p, end: parseSpace(p)), val: val)
  }
  
  func parseLitStr(pos: Pos) -> LitStr {
    let terminator = char(pos)
    var p = adv(pos)
    var res = ""
    var escape = false
    var ordPos: Pos? = nil
    var ordCount = 0
    while hasSome(p) {
      let c = char(p)
      if escape {
        escape = false
        var e: Character? = nil
        switch c {
        case "\\":  e = c
        case "'":   e = c
        case "\"":  e = c
        case "0":   e = "\0" // null.
        case "b":   e = "\u{08}" // backspace.
        case "n":   e = "\n"
        case "r":   e = "\r"
        case "t":   e = "\t"
        case "x":   ordPos = adv(p); ordCount = 2
        case "u":   ordPos = adv(p); ordCount = 4
        case "U":   ordPos = adv(p); ordCount = 6
        default:    failParse(p, nil, "invalid escape character")
        }
        if let e = e {
          res.append(e)
        }
      } else if ordCount > 0 {
        if !ployHexChars.contains(c) {
          failParse(p, nil, "escape ordinal must be a hexadecimal digit")
        }
        ordCount--
      } else {
        if let op = ordPos {
          if let ord = Int(slice(op, p), radix: 16) {
            if ord > 0x10ffff {
              failParse(op, p, "escaped unicode ordinal exceeds maximum value of 0x10ffff")
            }
            res.append(Character(UnicodeScalar(ord)))
          } else {
            failParse(op, p, "escaped unicode ordinal is invalid")
          }
          ordPos = nil
        }
        if c == "\\" {
          escape = true
        } else if c == terminator {
          let visEnd = adv(p)
          return LitStr(Syn(src: self, pos: pos, visEnd: visEnd, end: parseSpace(visEnd)), val: res)
        } else {
          res.append(c)
        }
      }
      p = adv(p)
    }
    failParse(pos, p, "unterminated string literal")
  }
  
  // MARK: compound helpers.
  
  func synForTerminator(pos: Pos, _ p: Pos, _ terminator: Character, _ formName: String) -> Syn {
    let c = char(p)
    if !hasSome(p) || c != terminator {
      failParse(pos, p, "`\(formName)` form expects '\(terminator)' terminator; received '\(c)'.")
    }
    let visEnd = adv(p)
    return Syn(src: self, pos: pos, visEnd: visEnd, end: parseSpace(visEnd))
  }
  
  func synForSemicolon(pos: Pos, _ p: Pos, _ formName: String) -> Syn {
    return synForTerminator(pos, p, ";", formName)
  }
  
  // MARK: prefixes.
  
  func parseBling(pos: Pos, _ p: Pos) -> Form {
    // in the future bling will also be a prefix.
    return Sym(Syn(src: self, pos: pos, visEnd: p, end: parseSpace(p)), name: "$")
  }
  
  // MARK: nesting sentences.
  
  func parseCmpd(pos: Pos, _ p: Pos) -> Form {
    let (args, end) = parseArgs(p, "compound value")
    return Cmpd(synForTerminator(pos, end, ")", "compound value"), args: args)
  }
  
  func parseCmpdType(pos: Pos, _ p: Pos) -> Form {
    let (pars, end) = parsePars(p, "compound type")
    return CmpdType(synForTerminator(pos, end, ">", "compound type"), pars: pars)
  }
  
  func parseDo(pos: Pos, _ p: Pos) -> Form {
    let (stmts, expr, _, end) = parseBody(p)
    return Do(synForTerminator(pos, end, "}", "do form"), stmts: stmts, expr: expr)
  }
  
  // MARK: keyword sentences.
  
  func parseEnum(sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`enum` form", "name symbol")
    var variants: [Par] = []
    let end = parseForms(&variants, nameSym.syn.end, "`enum` form", "variant parameter")
    return Enum(synForSemicolon(sym.syn.pos, end, "enum"), sym: nameSym, variants: variants)
  }
  
  func parseFn(sym: Sym) -> Form {
    let pos = sym.syn.pos
    let sig: Sig = parseForm(sym.syn.end, "`fn` form", "function signature")
    let do_ = parseBodyToImplicitDo(sig.syn.end)
    return Fn(synForSemicolon(pos, do_.syn.end, "fn"), sig: sig, body: do_)
  }
  
  func parseIf(sym: Sym) -> Form {
    let (forms, end) = parseRawForms(sym.syn.end)
    var cases: [Case] = []
    var dflt: Expr? = nil
    for (i, f) in forms.enumerate() {
      if let c = f as? Case {
        cases.append(c)
      } else if i == forms.lastIndex {
        let d: Expr = castForm(f, "`if` form", "default expression")
        dflt = d
      } else {
        f.failSyntax("`if` form expects `?` case but received \(f.syntaxName).")
      }
    }
    return If(synForSemicolon(sym.syn.pos, end, "`if` form"), cases: cases, dflt: dflt)
  }
  
  func parseIn(sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`in` form", "module name symbol")
    var defs: [Def] = []
    let end = parseForms(&defs, nameSym.syn.end, "`in` form", "definition")
    return In(synForSemicolon(sym.syn.pos, end, "`in` form"), sym: nameSym, defs: defs)
  }
  
  func parsePub(sym: Sym) -> Form {
    let def: Def = parseForm(sym.syn.end, "`pub` form", "definition")
    return Pub(Syn(sym.syn, def.syn), def: def)
  }
  
  func parseStruct(sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`struct` form", "name symbol")
    var fields: [Par] = []
    let end = parseForms(&fields, nameSym.syn.end, "`struct` form", "field parameter")
    return Struct(synForSemicolon(sym.syn.pos, end, "enum"), sym: nameSym, fields: fields)
  }
  
  func parseHostType(sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`host-type` form", "name symbol")
    return HostType(synForSemicolon(sym.syn.pos, nameSym.syn.end, "host-type"), sym: nameSym)
  }
  
  func parseHostVal(sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`host-val` form", "name symbol")
    let type: TypeExpr = parseForm(nameSym.syn.end, "`host-val` form", "type expression")
    return HostVal(synForSemicolon(sym.syn.pos, type.syn.end, "host-val"), sym: nameSym, type: type)
  }
  
  static let keywordSentenceHandlers: [String: (Src) -> (Sym) -> Form] = [
    "enum"      : parseEnum,
    "fn"        : parseFn,
    "if"        : parseIf,
    "in"        : parseIn,
    "pub"       : parsePub,
    "struct"    : parseStruct,
    "host-type" : parseHostType,
    "host-val"  : parseHostVal,
  ]
  
  // MARK: parse dispatch.
  
  func parsePoly(pos: Pos) -> Form {
    let c = char(pos)
    if ploySymHeadChars.contains(c) {
      var sym = parseSym(pos)
      if let handler = Src.keywordSentenceHandlers[sym.name] {
        return handler(self)(sym)
      }
      // path parsing.
      var syms = [sym]
      var p = sym.syn.end
      while !sym.syn.hasSpace && hasSome(p) && char(p) == "/" {
        p = adv(p)
        sym = parseSym(p)
        if Src.keywordSentenceHandlers.contains(sym.name) {
          sym.failSyntax("reserved keyword name cannot appear in path")
        }
        syms.append(sym)
        p = sym.syn.end
      }
      if syms.count > 1 {
        return Path(Syn(src: self, pos: pos, visEnd: sym.syn.visEnd, end: sym.syn.end), syms: syms)
      }
      return sym // regular sym.
    }
    if ployDecChars.contains(c) {
      return parseLitNum(pos)
    }
    if c == "\"" || c == "'" {
      return parseLitStr(pos)
    }
    let p = parseSpace(adv(pos))
    switch c {
    case ".": return parseLitNum(pos, foundDot: true)
    case "$": return parseBling(pos, p)
    case "(": return parseCmpd(pos, p)
    case "<": return parseCmpdType(pos, p)
    case "{": return parseDo(pos, p)
    default: failParse(pos, nil, "unexpected character: '\(c)'.")
    }
  }
  
  static let operator_groups: [[(String, (Form, Form)->Form)]] = [
    [ ("=", Bind.mk)],
    [ (":", Ann.mk)],
    [ ("@", Acc.mk),
      (".", Call.mk),
      ("?", Case.mk),
      ("^", Reify.mk),
      ("%", Sig.mk)]
  ]
  
  
  // TODO: currently unused.
  static let operator_characters = { () -> Set<Character> in
    var s = Set<Character>()
    for g in operator_groups {
      for (string, handler) in g {
        for c in string.characters {
          s.insert(c)
        }
      }
    }
    return s
  }()
  
  let adjacency_operators: [(Character, (Form, Form)->Form)] = [
    ("(", CallAdj.mk),
    ("^", ReifyAdj.mk)
  ]
  
  func parsePhrase(pos: Pos, precedence: Int = 0) -> Form {
    let left = parsePoly(pos)
    var p = left.syn.end
    if hasSome(p) {
      for i in precedence..<Src.operator_groups.count {
        let group = Src.operator_groups[i]
        for (string, handler) in group {
          if hasString(p, string) {
            p = adv(p, count: string.characters.count)
            p = parseSpace(p)
            let right = parsePhrase(p, precedence: i)
            return handler(left, right)
          }
        }
      }
      // adjacency operators have highest precedence.
      if !left.syn.hasSpace {
        for (c, handler) in adjacency_operators {
          if char(p) == c {
            let right = parsePhrase(p, precedence: Src.operator_groups.count) // TODO: decide if this should call parsePoly instead.
            return handler(left, right)
          }
        }
      }
    }
    return left
  }
  
  func parseForm<T>(pos: Pos, _ subj: String, _ exp: String) -> T {
    return castForm(parsePhrase(pos), subj, exp)
  }
  
  func parseForms<T>(inout forms: [T], _ pos: Pos, _ subj: String, _ exp: String) -> Pos {
    var p = parseSpace(pos)
    var prevSpace = true
    while hasSome(p) {
      if ployTerminatorChars.contains(char(p)) {
        break
      }
      if !prevSpace {
        failParse(p, nil, "adjacent expressions require a separating space.")
      }
      let form = parsePhrase(p)
      p = form.syn.end
      prevSpace = form.syn.hasSpace
      forms.append(castForm(form, subj, exp))
    }
    return p
  }
  
  func parseRawForms(pos: Pos) -> ([Form], Pos) {
    var forms: [Form] = []
    let end = parseForms(&forms, pos, "form", "any form (INTERNAL ERROR)")
    return (forms, end)
  }
  
  func parsePars(pos: Pos, _ subj: String) -> ([Par], Pos) {
    let (forms, end) = parseRawForms(pos)
    let pars = forms.enumerate().map { Par.mk(index: $0.index, form: $0.element, subj: subj) }
    return (pars, end)
  }
  
  func parseArgs(pos: Pos, _ subj: String) -> ([Arg], Pos) {
    let (forms, end) = parseRawForms(pos)
    let args = forms.map { Arg.mk($0, subj) }
    return (args, end)
  }
  
  func parseBody(pos: Pos) -> ([Stmt], Expr?, Pos, Pos) {
    let (forms, end) = parseRawForms(pos)
    var visEnd = end
    var stmts: [Stmt] = []
    var expr: Expr? = nil
    for (i, f) in forms.enumerate() {
      let isLast = (i == forms.lastIndex)
      if isLast {
        visEnd = f.syn.end
        if let e = f as? Expr {
          expr = e
          break
        }
      }
      if let s = f as? Stmt {
        stmts.append(s)
      } else {
        let exp = isLast ? "tail form to be either a statement or an expression" : "non-tail form to be a statement";
        f.failSyntax("body expects \(exp); received \(f.syntaxName).")
      }
    }
    return (stmts, expr, visEnd, end)
  }
  
  func parseBodyToImplicitDo(pos: Pos) -> Do {
    let (stmts, expr, visEnd, end) = parseBody(pos)
    return Do(Syn(src: self, pos: pos, visEnd: visEnd, end: end), stmts: stmts, expr: expr)
  }
  
  func parseMain(verbose verbose: Bool = false) -> ([In], Do) {
    let (forms, end) = parseRawForms(startPos)
    if hasSome(end) {
      failParse(end, nil, "unexpected terminator character: '\(char(end))'")
    }
    guard let last = forms.last else {
      fail(startPos, end, "syntax error", "empty main body; main requires a final Int exit code expression.")
    }
    guard let exitExpr = last as? Expr else {
      last.failSyntax("main body requires final form to be an Int exit code expression.")
    }
    var ins: [In] = []
    var stmts: [Stmt] = []
    for (i, f) in forms.enumerate() {
      if i == forms.lastIndex {
        break
      }
      if let in_ = f as? In {
        if stmts.count > 0 {
          in_.failSyntax("`in` forms must precede all statements in main body.", (stmts.last!, "preceding statement here"))
        }
        ins.append(in_)
      } else if let s = f as? Stmt {
        stmts.append(s)
      } else {
        f.failSyntax("main body expects `in` forms and statements; received \(f.syntaxName).")
      }
    }
    let bodyPos = (stmts.count > 0 ? stmts[0].syn.pos : exitExpr.syn.pos)
    let bodyDo = Do(Syn(src: self, pos: bodyPos, visEnd: exitExpr.syn.visEnd, end: exitExpr.syn.end), stmts: stmts, expr: exitExpr)
    return (ins, bodyDo)
  }
  
  func parseLib(verbose verbose: Bool = false) -> [In] {
    var ins: [In] = []
    let end = parseForms(&ins, startPos, "module", "`in` statement")
    if hasSome(end) {
      failParse(end, nil, "unexpected terminator character: '\(char(end))'")
    }
    if verbose {
      for i in ins {
        i.writeTo(&std_err)
      }
    }
    return ins
  }
}

