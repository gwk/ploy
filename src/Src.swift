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
    self.text = guarded { try InFile(path: path).readText() }
  }
  
  init(name: String) {
    self.path = name
    self.text = ""
  }
  
  var description: String { return "Src(\(path))" }
  
  var startPos: Pos { return Pos(idx: text.startIndex, line: 0, col: 0) }
  
  func adv(_ pos: Pos, count: Int = 1) -> Pos {
    var idx = pos.idx
    var c = count
    while c > 0 && idx < text.endIndex {
      idx = text.index(after: idx)
      c -= 1
    }
    return Pos(idx: idx, line: pos.line, col: pos.col + count)
  }
  
  func advLine(_ pos: Pos) -> Pos {
    assert(pos.idx < text.endIndex)
    let idx = text.index(after: pos.idx)
    return Pos(idx: idx, line: pos.line + 1, col: 0)
  }
  
  func hasSome(_ pos: Pos) -> Bool { return pos.idx < text.endIndex }
  
  func hasString(_ pos: Pos, _ string: String) -> Bool { return text.has(string, atIndex: pos.idx) }
  
  func char(_ pos: Pos) -> Character { return text[pos.idx] }
  
  func slice(_ pos: Pos, _ end: Pos) -> String { return text[pos.idx..<end.idx] }
  
  /// returns the line of source text containing pos; always excludes newline for consistency.
  func line(_ pos: Pos) -> String {
    var s = pos.idx
    while s > text.startIndex {
      let i = text.index(before: s)
      if text[i] == "\n" { break }
      s = i
    }
    var e = pos.idx
    while e < text.endIndex {
      if text[e] == "\n" { break }
      e = text.index(after: e)
    }
    return text[s..<e]
  }

  func underline(_ pos: Pos, _ end: Pos? = nil) -> String {
    let indent = String(repeating: Character(" "), count: pos.col)
    if let end = end {
      assert(pos.line == end.line)
      if pos.idx < end.idx {
        return indent + String(repeating: Character("~"), count: end.col - pos.col)
      }
    }
    return indent + "^"
  }
  
  func underlines(_ pos: Pos, _ end: Pos, lineLen: Int) -> (String, String) {
    assert(pos.line < end.line)
    let spaces = String(char: " ", count: pos.col)
    let squigs = String(char: "~", count: lineLen - pos.col)
    return ("\(spaces)\(squigs)", end.col > 0 ? String(char: "~", count: end.col) : "^")
  }

  func errPos(_ pos: Pos, end: Pos?, prefix: String, msg: String) {
    let msgSpace = msg.hasPrefix("\n") ? "" : " "
    let posLine = line(pos)
    err("\(prefix): \(path):\(pos.line + 1):")
    if let end = end {
      if pos.line == end.line { // single line.
        if pos.col < end.col { // multiple columns.
          err("\(pos.col + 1)-\(end.col):\(msgSpace)\(msg)\n  \(posLine)\n  \(underline(pos, end))\n")
          return
        }
      } else { // multiline.
        let endLine = line(end)
        let (underlinePos, underlineEnd) = underlines(pos, end, lineLen: posLine.characters.count)
        err("\(pos.col + 1)--\(end.line + 1):\(end.col):\(msgSpace)\(msg)\n")
        err("  \(posLine)\n  \(underlinePos)…\n")
        err("  \(endLine)\n …\(underlineEnd)\n")
        return
      }
    }
    // single line, single column.
    err("\(pos.col + 1):\(msgSpace)\(msg)\n  \(posLine)\n  \(underline(pos))\n")
  }

  @noreturn func fail(_ pos: Pos, _ end: Pos?, _ prefix: String, _ msg: String) {
    errPos(pos, end: end, prefix: prefix, msg: msg)
    Process.exit(1)
  }

  @noreturn func failParse(_ pos: Pos, _ end: Pos?, _ msg: String) { fail(pos, end, "parse error", msg) }

  func parseSpace(_ pos: Pos) -> Pos {
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
  
  func parseSym(_ pos: Pos) -> Sym {
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
  
  func parseLitNum(_ pos: Pos, foundDot: Bool = false) -> LitNum {
    var foundDot = foundDot
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
  
  func parseLitStr(_ pos: Pos) -> LitStr {
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
        ordCount -= 1
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
  
  func synForTerminator(_ pos: Pos, _ p: Pos, _ terminator: Character, _ formName: String) -> Syn {
    if !hasSome(p) {
      failParse(pos, p, "`\(formName)` form expects '\(terminator)' terminator; reached end of source text.")
    }
    let c = char(p)
    if c != terminator {
      failParse(pos, p, "`\(formName)` form expects '\(terminator)' terminator; received '\(c)'.")
    }
    let visEnd = adv(p)
    return Syn(src: self, pos: pos, visEnd: visEnd, end: parseSpace(visEnd))
  }
  
  func synForSemicolon(_ sym: Sym, _ p: Pos, _ formName: String) -> Syn {
    return synForTerminator(sym.syn.pos, p, ";", formName)
  }
  
  // MARK: prefixes.
  
  func parseBling(_ pos: Pos) -> Form {
    // in the future bling will also be a prefix.
    let p = adv(pos)
    return Sym(Syn(src: self, pos: pos, visEnd: p, end: parseSpace(p)), name: "$")
  }
  
  // MARK: nesting sentences.
  
  func parseCmpdOrParen(_ pos: Pos) -> Form {
    let p = parseSpace(adv(pos))
    let (args, end) = parseArgs(p, "compound value")
    if args.count == 1 {
      let arg = args[0]
      if let label = arg.label {
        label.failSyntax("label implies disallowed single-element compound expression")
      } else {
        return Paren(synForTerminator(pos, end, ")", "parenthesized expression"), expr: arg.expr)
      }
    } else {
      return Cmpd(synForTerminator(pos, end, ")", "compound expression"), args: args)
    }
  }
  
  func parseCmpdType(_ pos: Pos) -> Form {
    let p = parseSpace(adv(pos))
    let (pars, end) = parsePars(p, "compound type")
    return CmpdType(synForTerminator(pos, end, ">", "compound type"), pars: pars)
  }
  
  func parseDo(_ pos: Pos) -> Form {
    let p = parseSpace(adv(pos))
    let (exprs, _, end) = parseBody(p)
    return Do(synForTerminator(pos, end, "}", "do form"), exprs: exprs)
  }
  
  // MARK: keyword sentences.
  
  func parseEnum(_ sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`enum` form", "name symbol")
    var variants: [Par] = []
    let end = parseForms(&variants, nameSym.syn.end, "`enum` form", "variant parameter")
    return Enum(synForSemicolon(sym, end, "enum"), sym: nameSym, variants: variants)
  }
  
  func parseFn(_ sym: Sym) -> Form {
    let sig: Sig = parseForm(sym.syn.end, "`fn` form", "function signature")
    let do_ = parseBodyToImplicitDo(sig.syn.end)
    return Fn(synForSemicolon(sym, do_.syn.end, "fn"), sig: sig, body: do_)
  }
  
  func parseHostType(_ sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`host-type` form", "name symbol")
    return HostType(synForSemicolon(sym, nameSym.syn.end, "host-type"), sym: nameSym)
  }
  
  func parseHostVal(_ sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`host-val` form", "name symbol")
    let typeExpr: TypeExpr = parseForm(nameSym.syn.end, "`host-val` form", "type expression")
    return HostVal(synForSemicolon(sym, typeExpr.syn.end, "host-val"), sym: nameSym, typeExpr: typeExpr)
  }
  
  func parseIf(_ sym: Sym) -> Form {
    let (forms, end) = parseRawForms(sym.syn.end)
    var cases: [Case] = []
    var dflt: Expr? = nil
    for (i, f) in forms.enumerated() {
      if let c = f as? Case {
        cases.append(c)
      } else if i == forms.lastIndex {
        let d: Expr = castForm(f, "`if` form", "default expression")
        dflt = d
      } else {
        f.failSyntax("`if` form expects `?` case but received \(f.syntaxName).")
      }
    }
    return If(synForSemicolon(sym, end, "`if` form"), cases: cases, dflt: dflt)
  }
  
  func parseIn(_ sym: Sym) -> Form {
    let identifier: Identifier = parseForm(sym.syn.end, "`in` form", "module name symbol")
    var defs: [Def] = []
    let end = parseForms(&defs, identifier.syn.end, "`in` form", "definition")
    return In(synForSemicolon(sym, end, "`in` form"), identifier: identifier, defs: defs)
  }
  
  func parseMethod(_ sym: Sym) -> Form {
    let identifier: Identifier = parseForm(sym.syn.end, "`method` form", "poly-fn name or path identifier")
    let sig: Sig = parseForm(identifier.syn.end, "`method` form", "method signature")
    let body = parseBodyToImplicitDo(sig.syn.end)
    return Method(synForSemicolon(sym, body.syn.end, "method"), identifier: identifier, sig: sig, body: body)
  }

  func parsePolyFn(_ sym: Sym) -> Form {
    let nameSym = parseSym(sym.syn.end)
    // TODO: type constraint.
    return PolyFn(synForSemicolon(sym, nameSym.syn.end, "poly-fn"), sym: nameSym)
  }
  
  func parsePub(_ sym: Sym) -> Form {
    let def: Def = parseForm(sym.syn.end, "`pub` form", "definition")
    return Pub(Syn(sym.syn, def.syn), def: def)
  }
  
  func parseStruct(_ sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, "`struct` form", "name symbol")
    var fields: [Par] = []
    let end = parseForms(&fields, nameSym.syn.end, "`struct` form", "field parameter")
    return Struct(synForSemicolon(sym, end, "enum"), sym: nameSym, fields: fields)
  }
  
  static let keywordSentenceHandlers: [String: (Src) -> (Sym) -> Form] = [
    "enum"      : parseEnum,
    "fn"        : parseFn,
    "host-type" : parseHostType,
    "host-val"  : parseHostVal,
    "if"        : parseIf,
    "in"        : parseIn,
    "method"    : parseMethod,
    "poly-fn"   : parsePolyFn,
    "pub"       : parsePub,
    "struct"    : parseStruct,
  ]
  
  // MARK: parse dispatch.
  
  func parsePoly(_ pos: Pos) -> Form {
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
    switch c {
    case ".": return parseLitNum(pos, foundDot: true)
    case "$": return parseBling(pos)
    case "(": return parseCmpdOrParen(pos)
    case "<": return parseCmpdType(pos)
    case "{": return parseDo(pos)
    default: failParse(pos, nil, "unexpected character: '\(c)'.")
    }
  }
  
  static let operator_groups: [[(String, (Form, Form)->Form)]] = [
    [ ("=", Bind.mk),
      ("?", Case.mk)],
    [ (":", Ann.mk)],
    [ ("@", Acc.mk),
      (".", Call.mk),
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
    ("<", ReifyAdj.mk)
  ]
  
  func parsePhrase(_ pos: Pos, precedence: Int = 0) -> Form {
    var left = parsePoly(pos)
    var p = left.syn.end
    outer: while hasSome(p) {
      for i in precedence..<Src.operator_groups.count {
        let group = Src.operator_groups[i]
        for (string, handler) in group {
          if hasString(p, string) {
            p = adv(p, count: string.characters.count)
            p = parseSpace(p)
            let right = parsePhrase(p, precedence: i)
            left = handler(left, right)
            p = left.syn.end
            continue outer
          }
        }
      }
      // adjacency operators have highest precedence.
      if !left.syn.hasSpace {
        for (c, handler) in adjacency_operators {
          if char(p) == c {
            let right = parsePhrase(p, precedence: Src.operator_groups.count) // TODO: decide if this should call parsePoly instead.
            left = handler(left, right)
            p = left.syn.end
            continue outer
          }
        }
      }
      break
    }
    return left
  }
  
  func parseForm<T>(_ pos: Pos, _ subj: String, _ exp: String) -> T {
    return castForm(parsePhrase(pos), subj, exp)
  }
  
  func parseForms<T>(_ forms: inout [T], _ pos: Pos, _ subj: String, _ exp: String) -> Pos {
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
  
  func parseRawForms(_ pos: Pos) -> ([Form], Pos) {
    var forms: [Form] = []
    let end = parseForms(&forms, pos, "form", "any form (INTERNAL ERROR)")
    return (forms, end)
  }
  
  func parsePars(_ pos: Pos, _ subj: String) -> ([Par], Pos) {
    let (forms, end) = parseRawForms(pos)
    let pars = forms.enumerated().map { Par.mk(index: $0.offset, form: $0.element, subj: subj) }
    return (pars, end)
  }
  
  func parseArgs(_ pos: Pos, _ subj: String) -> ([Arg], Pos) {
    let (forms, end) = parseRawForms(pos)
    let args = forms.map { Arg.mk($0, subj) }
    return (args, end)
  }
  
  func parseBody(_ pos: Pos) -> ([Expr], Pos, Pos) {
    let (forms, end) = parseRawForms(pos)
    let exprs: [Expr] = forms.map { castForm($0, "body", "expression") }
    let visEnd = (exprs.last?.syn.end).or(end)
    return (exprs, visEnd, end)
  }
  
  func parseBodyToImplicitDo(_ pos: Pos) -> Do {
    let (exprs, visEnd, end) = parseBody(pos)
    return Do(Syn(src: self, pos: pos, visEnd: visEnd, end: end), exprs: exprs)
  }
  
  func parseMain(verbose: Bool = false) -> (ins: [In], mainIn: In) {
    let (forms, end) = parseRawForms(startPos)
    if hasSome(end) {
      failParse(end, nil, "unexpected terminator character: '\(char(end))'")
    }
    var ins: [In] = []
    var defs: [Def] = []
    for form in forms {
      if let in_ = form as? In {
        if defs.count > 0 {
          in_.failSyntax("`in` forms must precede all definitions in main.",
            notes: (defs.first!, "first definition here"))
        }
        ins.append(in_)
      } else if let def = form as? Def {
        defs.append(def)
      } else {
        form.failSyntax("main file expects `in` forms and definitions; received \(form.syntaxName).")
      }
    }
    let mainPos = (defs.first?.syn.pos).or(end)
    let mainVisEnd = (defs.last?.syn.visEnd).or(end)
    let mainEnd = (defs.last?.syn.end).or(end)
    let mainIn = In(Syn(src: self, pos: mainPos, visEnd: mainVisEnd, end: mainEnd), identifier: nil, defs: defs)
    if verbose {
      for in_ in ins {
        in_.write(to: &std_err)
      }
      mainIn.write(to: &std_err)
    }
    return (ins, mainIn)
  }
  
  func parseLib(verbose: Bool = false) -> [In] {
    var ins: [In] = []
    let end = parseForms(&ins, startPos, "module", "`in` statement")
    if hasSome(end) {
      failParse(end, nil, "unexpected terminator character: '\(char(end))'")
    }
    if verbose {
      for i in ins {
        i.write(to: &std_err)
      }
    }
    return ins
  }
}

