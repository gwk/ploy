// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Darwin


let ployOctChars = Set("_01234567".characters)
let ployDecChars = Set("_0123456789".characters)
let ployHexChars = Set("_0123456789ABCDEFabcdef".characters)
let ployNumHeadChars = ployDecChars.union(".".characters)
let ploySymHeadChars = Set("_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".characters)
let ploySymTailChars = ploySymHeadChars.union(ployDecChars)
let ployTerminatorChars = Set(")>]};".characters)


class Src: CustomStringConvertible {
  let path: String
  let text: String

  init(path: String) {
    self.path = path
    self.text = guarded { try String(contentsOfFile: path) }
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

  func match(pos: Pos, string: String) -> Bool {
    return text.contains(string: string, atIndex: pos.idx)
  }

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
    let indent = String(repeating: " ", count: pos.col)
    if let end = end {
      assert(pos.line == end.line)
      if pos.idx < end.idx {
        return indent + String(repeating: "~", count: end.col - pos.col)
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

  func fail(_ pos: Pos, _ end: Pos?, _ prefix: String, _ msg: String) -> Never {
    errPos(pos, end: end, prefix: prefix, msg: msg)
    exit(1)
  }

  func failParse(_ pos: Pos, _ end: Pos?, _ msg: String) -> Never {
    fail(pos, end, "parse error", msg)
  }

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
      if prev == "_" && c == "_" {
        failParse(p, nil, "symbols cannot contain repeated '_' characters.")
      }
      prev = c
      p = adv(p)
    }
    return Sym(Syn(src: self, pos: pos, visEnd: p, end: parseSpace(p)), name: slice(pos, p))
  }

  func parseLitNum(_ pos: Pos) -> LitNum {
    let leadChar = char(pos)
    assert(leadChar == "-" || ployNumHeadChars.contains(leadChar))
    var foundDot = (leadChar == ".")
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
    if string == "." || string == "-" {
      failParse(pos, p, "incomplete number literal.")
    }
    if foundDot {
      failParse(pos, p, "floating point literals are not yet supported.")
    }
    guard let val = Int(string, radix: 10) else {
      failParse(pos, p, "invalid number literal (PLOY COMPILER ERROR).")
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
            res.append(Character(UnicodeScalar(ord)!))
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

  func parseDash(_ pos: Pos) -> Form {
    let nextPos = adv(pos)
    if !hasSome(nextPos) {
      failParse(pos, nil, "dangling dash at end of file.")
    }
    let nextChar = char(nextPos)
    if ployNumHeadChars.contains(nextChar) {
      return parseLitNum(pos)
    } else if ploySymHeadChars.contains(nextChar) {
      let sym = parseSym(nextPos)
      return Tag(Syn(pos: pos, bodySyn: sym.syn), sym: sym)
    }
    failParse(pos, nil, "dash must be followed by numeric literal or symbol.")
  }

  func parseSlash(_ pos: Pos) -> Form {
    let p = parseSpace(adv(pos))
    if !hasSome(p) {
      failParse(pos, nil, "dangling slash at end of file.")
    }
    let expr: Expr = parseSubForm(p, subj: "`/` form")
    return Default(Syn(pos: pos, bodySyn: expr.syn), expr: expr)
  }

  // MARK: nesting sentences.

  func parseParen(_ pos: Pos) -> Form {
    let p = parseSpace(adv(pos))
    var els: [Expr] = []
    let end = parseSubForms(&els, p, subj: "parenthesized expression")
    return Paren(synForTerminator(pos, end, ")", "parenthesized expression"), els: els)
  }

  func parseTypeConstraint(_ pos: Pos) -> Form {
    let p = parseSpace(adv(pos))
    var pars: [Expr] = []
    let end = parseSubForms(&pars, p, subj: "type constraint")
    return TypeConstraint(synForTerminator(pos, end, ">", "type constraint"), pars: pars)
  }

  func parseDo(_ pos: Pos) -> Form {
    let p = parseSpace(adv(pos))
    let body = parseBody(p, subj: "do form")
    return Do(synForTerminator(pos, body.syn.end, "}", "do form"), body: body)
  }

  // MARK: keyword sentences.

  func parseAnd(_ sym: Sym) -> Form {
    var terms: [Expr] = []
    let end = parseSubForms(&terms, sym.syn.end, subj: "`and` form")
    return And(synForSemicolon(sym, end, "and"), terms: terms)
  }

  func parseOr(_ sym: Sym) -> Form {
    var terms: [Expr] = []
    let end = parseSubForms(&terms, sym.syn.end, subj: "`or` form")
    return Or(synForSemicolon(sym, end, "or"), terms: terms)
  }

  func parseExtensible(_ sym: Sym) -> Form {
    var constraints: [Expr] = []
    let nameSym: Sym = parseForm(sym.syn.end, subj: "`extensible` form", exp: "name symbol")
    let end = parseSubForms(&constraints, nameSym.syn.end, subj: "extensible type constraints")
    return Extensible(synForSemicolon(sym, end, "extensible"), sym: nameSym, constraints: constraints)
  }

  func parseFn(_ sym: Sym) -> Form {
    let sig: Sig = parseForm(sym.syn.end, subj: "`fn` form", exp: "function signature")
    let body = parseBody(sig.syn.end, subj: "`fn` form")
    return Fn(synForSemicolon(sym, body.syn.end, "fn"), sig: sig, body: body)
  }

  func parseHostType(_ sym: Sym) -> Form {
    let nameSym: Sym = parseForm(sym.syn.end, subj: "`host_type` form", exp: "name symbol")
    return HostType(synForSemicolon(sym, nameSym.syn.end, "host_type"), sym: nameSym)
  }

  func parseHostVal(_ sym: Sym) -> Form {
    let typeExpr: Expr = parseSubForm(sym.syn.end, subj: "`host_val` form")
    let code: LitStr = parseForm(typeExpr.syn.end, subj: "`host_val` form", exp: "code string")
    var deps: [Identifier] = []
    let end = parseSubForms(&deps, code.syn.end, subj: "`host_val` form")
    return HostVal(synForSemicolon(sym, end, "host_val"), typeExpr: typeExpr, code: code, deps: deps)
  }

  func parseIf(_ sym: Sym) -> Form {
    var clauses: [Clause] = []
    let end = parseSubForms(&clauses, sym.syn.end, subj: "`if` form")
    var cases: [Case] = []
    var dflt: Default? = nil
    for (i, clause) in clauses.enumerated() {
      switch clause {
      case .case_(let case_): cases.append(case_)
      case .default_(let default_):
        if i == clauses.lastIndex {
          dflt = default_
        } else {
          default_.failSyntax("`if` form requires `?` case clauses in all but final position; received `/` default clause.")
        }
      }
    }
    return If(synForSemicolon(sym, end, "`if` form"), cases: cases, dflt: dflt)
  }

  func parseIn(_ sym: Sym) -> Form {
    let identifier: Identifier = parseSubForm(sym.syn.end, subj: "`in` form")
    var defs: [Def] = []
    let end = parseSubForms(&defs, identifier.syn.end, subj: "`in` form")
    return In(synForSemicolon(sym, end, "`in` form"), identifier: identifier, defs: defs)
  }

  func parseMatch(_ sym: Sym) -> Form {
    let expr: Expr = parseSubForm(sym.syn.end, subj: "`match` form")
    var clauses: [Clause] = []
    let end = parseSubForms(&clauses, expr.syn.end, subj: "`match` form")
    var cases: [Case] = []
    var dflt: Default? = nil
    for (i, clause) in clauses.enumerated() {
      switch clause {
      case .case_(let case_): cases.append(case_)
      case .default_(let default_):
        if i == clauses.lastIndex {
          dflt = default_
        } else {
          default_.failSyntax("`match` form requires `?` case clauses in all but final position; received `/` default clause.")
        }
      }
    }
    return Match(synForSemicolon(sym, end, "`match` form"), expr: expr, cases: cases, dflt: dflt)
  }

  func parsePub(_ sym: Sym) -> Form {
    let def: Def = parseSubForm(sym.syn.end, subj: "`pub` form")
    return Pub(Syn(sym.syn, def.syn), def: def)
  }

  static let keywordSentenceHandlers: [String: (Src) -> (Sym) -> Form] = [
    "and"         : parseAnd,
    "extensible"  : parseExtensible,
    "fn"          : parseFn,
    "host_type"   : parseHostType,
    "host_val"    : parseHostVal,
    "if"          : parseIf,
    "in"          : parseIn,
    "match"       : parseMatch,
    "or"          : parseOr,
    "pub"         : parsePub,
  ]

  // MARK: parse dispatch.

  func parseSentenceSymOrPath(_ pos: Pos) -> Form {
    var sym = parseSym(pos)
    if let handler = Src.keywordSentenceHandlers[sym.name] {
      return handler(self)(sym)
    }
    // path parsing.
    var syms = [sym]
    var p = sym.syn.end
    while !sym.syn.hasEndSpace && hasSome(p) && char(p) == "/" {
      p = adv(p)
      sym = parseSym(p)
      if Src.keywordSentenceHandlers.contains(key: sym.name) {
        sym.failSyntax("reserved keyword")
      }
      if jsReservedWords.contains(sym.name) {
        sym.failSyntax("reserved word (temporary requirment for JavaScript compatibility)")
      }
      syms.append(sym)
      p = sym.syn.end
    }
    if syms.count > 1 {
      return Path(Syn(src: self, pos: pos, visEnd: sym.syn.visEnd, end: sym.syn.end), syms: syms)
    }
    return sym // regular sym.
  }

  func parsePoly(_ pos: Pos) -> Form {
    let c = char(pos)
    if ploySymHeadChars.contains(c) {
      return parseSentenceSymOrPath(pos)
    }
    if ployNumHeadChars.contains(c) {
      return parseLitNum(pos)
    }
    if c == "\"" || c == "'" {
      return parseLitStr(pos)
    }
    switch c {
    case "$": return parseBling(pos)
    case "-": return parseDash(pos)
    case "/": return parseSlash(pos)
    case "(": return parseParen(pos)
    case "<": return parseTypeConstraint(pos)
    case "{": return parseDo(pos)
    default: failParse(pos, nil, "unexpected character: '\(c)'.")
    }
  }

  static let opGroups: [[(String, (Form, Form)->Form)]] = [
    [ ("=:", TypeAlias.mk),
      ("=", Bind.mk),
      ("+=", Extension.mk),
      ("?", Case.mk)],
    [ ("|", Union.mk)],
    [ ("::", Where.mk),
      (":", Ann.mk)],
    [ ("@?", TagTest.mk),
      ("@", Acc.mk),
      (".", Call.mk),
      ("^", Reify.mk),
      ("%", Sig.mk)]
    ]

  // precedence is repeated for spaced and unspaced operators.
  static let opPrecedenceGroups = opGroups + opGroups
  static let unspacedPrecedence = opGroups.count

  // note: currently unused.
  static let operatorCharacters = { () -> Set<Character> in
    var s = Set<Character>()
    for g in opGroups {
      for (string, _) in g {
        for c in string.characters {
          s.insert(c)
        }
      }
    }
    return s
  }()

  let adjacencyOperators: [(Character, (Form, Form)->Form)] = [
    ("(", CallAdj.mk),
  ]

  func parsePhrase(_ pos: Pos, precedence: Int = 0) -> Form {
    var left = parsePoly(pos)
    var p = left.syn.end
    outer: while hasSome(p) {
      let leftSpace = left.syn.hasEndSpace
      for i in precedence..<Src.opPrecedenceGroups.count {
        let group = Src.opPrecedenceGroups[i]
        for (string, handler) in group {
          let expSpace = (i < Src.unspacedPrecedence)
          if (leftSpace == expSpace) && match(pos: p, string: string) {
            let opVisEnd = adv(p, count: string.characters.count)
            let rightPos = parseSpace(opVisEnd)
            let rightSpace = (opVisEnd.idx < rightPos.idx)
            if leftSpace != rightSpace {
              failParse(left.syn.visEnd, rightPos, "mismatched space around operator")
            }
            let right = parsePhrase(rightPos, precedence: i)
            left = handler(left, right)
            p = left.syn.end
            continue outer
          }
        }
      }
      // adjacency operators have highest precedence.
      if !leftSpace {
        for (c, handler) in adjacencyOperators {
          if char(p) == c {
            let right = parsePhrase(p, precedence: Src.opPrecedenceGroups.count) // TODO: decide if this should call parsePoly instead.
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

  func parseForm<T: Form>(_ pos: Pos, subj: String, exp: String) -> T {
    let form = parsePhrase(pos)
    if let form = form as? T {
      return form
    } else {
      form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
    }
  }

  func parseSubForm<T: SubForm>(_ pos: Pos, subj: String, allowSpaces: Bool = true) -> T {
    return T(form: parsePhrase(pos, precedence: (allowSpaces ? 0 : Src.unspacedPrecedence)), subj: subj)
  }

  func parseSubForms<T: SubForm>(_ subForms: inout [T], _ pos: Pos, subj: String) -> Pos {
    var p = parseSpace(pos)
    var prevSpace = true
    while hasSome(p) {
      if ployTerminatorChars.contains(char(p)) {
        break
      }
      if !prevSpace {
        failParse(p, nil, "adjacent forms require a separating space.")
      }
      let form: T = parseSubForm(p, subj: subj)
      p = form.syn.end
      prevSpace = form.syn.hasEndSpace
      subForms.append(form)
    }
    return p
  }

  func parseBody(_ pos: Pos, subj: String) -> Body {
    var exprs: [Expr] = []
    let end = parseSubForms(&exprs, pos, subj: "body")
    return Body(Syn(src: self, pos: pos, visEnd: exprs.last?.syn.visEnd ?? pos, end: end), exprs: exprs)
  }

  func parse(verbose: Bool = false) -> [Def] {
    var defs: [Def] = []
    let end = parseSubForms(&defs, startPos, subj: "top level")
    if hasSome(end) {
      failParse(end, nil, "unexpected terminator character: '\(char(end))'")
    }
    if verbose {
      for def in defs {
        def.write(to: &std_err)
      }
    }
    return defs
  }
}
