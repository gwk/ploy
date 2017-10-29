// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Darwin


func parsePloy(path: Path) -> [Def] {
  do {
    let bytes = try File(path: path).readBytes()
    let source = Source(name: path.expandUser, text: bytes)
    let parser = Parser(source: source)
    return parser.parse()
  } catch let e as File.Err {
    fail("could not read source file: \(path)\n  \(e)")
  } catch { fatalError() }
}


class Parser {
  let source: Source
  let tokens: [Token]
  var tokenPos: Int = 0

  init(source: Source) {
    self.source = source
    self.tokens = Array(source.lex())
  }

  var atEnd: Bool { return tokenPos == tokens.count }
  var current: Token { return tokens[tokenPos] }


  func parse() -> [Def] {
    if tokens.isEmpty { return [] }
    let defs: [Def] = parseSubForms(subj: "top level")
    if !atEnd { failParse("unexpected terminator token: \(current.kind)") }
    return defs
  }


  func parseForm<T: Form>(subj: String, exp: String) -> T {
    let form = parsePhrase(precedence: 0)
    if let form = form as? T { return form }
    form.failSyntax("\(subj) expected \(exp); received \(form.syntaxName).")
  }


  func parseSubForm<T: SubForm>(subj: String, allowSpaces: Bool = true) -> T {
    let form = parsePhrase(precedence: (allowSpaces ? 0 : Parser.unspacedPrecedence))
    if let subForm = T(form: form) { return subForm }
    form.failSyntax("\(subj) expected \(T.parseExpDesc); received \(form.syntaxName).")
  }


  func parseSubForms<T: SubForm>(subj: String) -> [T] {
    _ = parseSpace()
    var prevSpace = true
    var subForms: [T] = []
    while !atEnd {
      if Parser.terminators.contains(current.kind) {
        break
      }
      if !prevSpace {
        failParse("adjacent forms require a separating space.")
      }
      let form: T = parseSubForm(subj: subj)
      prevSpace = form.syn.hasEndSpace
      subForms.append(form)
    }
    return subForms
  }

  static let terminators: Set<TokenKind> = [.semicolon, .parenC, .braceC, .brackC, .angleC]


  func parseBody(subj: String) -> Body {
    let exprs: [Expr] = parseSubForms(subj: "body")
    if atEnd { failEnd("\(subj) reached end of file.") }
    let syn: Syn
    if let hd = exprs.first?.syn, let tl = exprs.last?.syn {
      syn = Syn(hd, tl)
    } else {
      syn = Syn(source: source, lineIdx: current.lineIdx, linePos: current.linePos, pos: current.pos, visEnd: current.pos, end: current.pos)
    }
    return Body(syn, exprs: exprs)
  }


  func parsePhrase(precedence: Int) -> Form {
    if atEnd { failEnd("reached end of file.") }
    var left = parsePoly()
    outer: while !atEnd {
      let leftSpace = left.syn.hasEndSpace
      for i in precedence..<Parser.opPrecedenceGroups.count {
        let group = Parser.opPrecedenceGroups[i]
        for (kind, handler) in group {
          let expSpace = (i < Parser.unspacedPrecedence)
          if (leftSpace == expSpace) && current.kind == kind {
            let opToken = current
            advance()
            let pos = tokenPos
            _ = parseSpace()
            let rightSpace = (pos < tokenPos)
            if leftSpace != rightSpace {
              failParse(token: opToken, "mismatched space around operator")
            }
            let right = parsePhrase(precedence: i)
            left = handler(left, right)
            continue outer
          }
        }
      }
      // adjacency operators have highest precedence.
      if !leftSpace {
        for (kind, handler) in Parser.adjacencyOperators {
          if current.kind == kind {
            let right = parsePhrase(precedence: Parser.opPrecedenceGroups.count) // TODO: decide if this should call parsePoly instead.
            left = handler(left, right)
            continue outer
          }
        }
      }
      break
    }
    return left
  }

  static let opGroups: [[(TokenKind, (Form, Form)->Form)]] = [
    [ (.typeAlias, TypeAlias.mk),
      (.bind, Bind.mk),
      (.extension_, Extension.mk),
      (.case_, Case.mk)],
    [ (.union, Union.mk)],
    [ (.where_, Where.mk),
      (.ann, Ann.mk)],
    [ (.tagTest, TagTest.mk),
      (.acc, Acc.mk),
      (.call, Call.mk),
      (.sig, Sig.mk)]
    ]

  // precedence is repeated for spaced and unspaced operators.
  static let opPrecedenceGroups = opGroups + opGroups
  static let unspacedPrecedence = opGroups.count

  static let adjacencyOperators: [(TokenKind, (Form, Form)->Form)] = [
    (.parenO, CallAdj.mk),
    (.angleO, Reif.mk),
  ]


  func parsePoly() -> Form {
    switch current.kind {
    case .and: return parseAnd()
    case .extensible: return parseExtensible()
    case .fn: return parseFn()
    case .host_type: return parseHostType()
    case .host_val: return parseHostVal()
    case .if_: return parseIf()
    case .in_: return parseIn()
    case .match: return parseMatch()
    case .or: return parseOr()
    case .pub: return parsePub()
    case .sym: return parseSymOrPath()
    case .int, .intDec, .intBin, .intQuat, .intOct, .intHex: return parseLitNum()
    case .stringDQ, .stringSQ: return parseLitStr()
    case .bling: return parseBling()
    case .caret: return parseCaret()
    case .dash: return parseDash()
    case .slash: return parseSlash()
    case .parenO: return parseParen()
    case .angleO: return parseTypeArgs()
    case .braceO: return parseDo()
    default: failParse("unexpected token: \(current.kind).")
    }
  }


  func parseSymOrPath() -> Form {
    var sym = parseSym()
    var syms = [sym]
    while !atEnd && !sym.syn.hasEndSpace && current.kind == .slash {
      advance()
      if current.kind != .sym { break }
      sym = parseSym()
      if jsReservedWords.contains(sym.name) {
        sym.failSyntax("reserved word (temporary requirment for JavaScript compatibility)")
      }
      syms.append(sym)
    }
    if syms.count > 1 {
      return SymPath(Syn(syms.first!.syn, syms.last!.syn), syms: syms)
    } else {
      return sym
    }
  }


  // MARK: leaves.


  func parseSym() -> Sym {
    let token = getCurrentAndAdvance()
    var underscore = false
    for pos in token.range {
      let byte = source.text[pos]
      if byte == "_" {
        if underscore {
          errZ(source.diagnostic(pos: pos, linePos: token.linePos, lineIdx: token.lineIdx,
            msg: "lexical error: symbols cannot contain repeated '_' characters."))
          exit(1)
        } else {
          underscore = true
        }
      } else {
        underscore = false
      }
    }
    return Sym(Syn(source: source, token: token, end: parseSpace()), name: slice(token.pos, token.end))
  }


  func parseLitNum() -> LitNum {
    do {
      let val = try source.parseSignedNumber(token: current)
      let token = getCurrentAndAdvance()
      return LitNum(Syn(source: source, token: token, end: parseSpace()), val: Int(val))
    } catch let e as Source.Err {
      switch e {
      case .overflow: failParse("integer literal value overflows I64.")
      }
    } catch { fatalError() }
  }


  func parseLitStr() -> LitStr {
    var val = ""
    var escape = false
    var ordPos: Int? = nil
    var ordCount = 0
    for pos in current.subRange(from: 1, beforeEnd: 1) {
      let byte = source.text[pos]
      if escape {
        escape = false
        var e: Character? = nil
        switch byte {
        case "\\":  e = "\\"
        case "'":   e = "'"
        case "\"":  e = "\""
        case "0":   e = "\0" // null.
        case "b":   e = "\u{08}" // backspace.
        case "n":   e = "\n"
        case "r":   e = "\r"
        case "t":   e = "\t"
        case "x":   ordPos = pos + 1; ordCount = 2
        case "u":   ordPos = pos + 1; ordCount = 4
        case "U":   ordPos = pos + 1; ordCount = 6
        default: failParse("invalid escape character")
        }
        if let e = e {
          val.append(e)
        }
      } else if ordCount > 0 {
        if !Parser.hexChars.contains(byte) {
          failParse("escape ordinal must be a hexadecimal digit")
        }
        ordCount -= 1
      } else {
        if let _ordPos = ordPos {
          if let ord = Int(slice(_ordPos, pos), radix: 16) {
            if ord > 0x10ffff {
              failParse("escaped unicode ordinal exceeds maximum value of 0x10ffff")
            }
            val.append(Character(UnicodeScalar(ord)!))
          } else {
            failParse("escaped unicode ordinal is invalid")
          }
          ordPos = nil
        }
        if byte == "\\" {
          escape = true
        } else {
          val.append(Character(Unicode.Scalar(byte)))
        }
      }
    }
    let token = getCurrentAndAdvance()
    return LitStr(Syn(source: source, token: token, end: parseSpace()), val: val)
  }

  static let hexChars = Set("_0123456789ABCDEFabcdef".unicodeScalars.map { UInt8($0.value) })


  // MARK: compound helpers.


  func synForTerminator(head: Token, terminator: TokenKind, _ formName: String) -> Syn {
    if atEnd {
      failParse(token: head, "`\(formName)` form expected \(terminator) terminator; reached end of file.")
      // TODO: report correct position.
    }
    if current.kind != terminator {
      failParse("`\(formName)` form expected \(terminator) terminator; received '\(current.kind)'.")
    }
    let visEnd = current.end
    advance()
    return Syn(source: source, token: head, visEnd: visEnd, end: parseSpace())
  }


  func synForSemicolon(head: Token, _ formName: String) -> Syn {
    return synForTerminator(head: head, terminator: .semicolon, formName)
  }


  // MARK: prefixes.


  func parseBling() -> Form {
    let head = getCurrentAndAdvance()
    return Sym(Syn(source: source, token: head, end: parseSpace()), name: "$")
  }


  func parseCaret() -> Form {
    let head = getCurrentAndAdvance()
    if atEnd { failParse(token: head, "dangling caret at end of file.") }
    if current.kind != .sym {
      failParse("caret must be followed by a symbol.")
    }
    let sym = parseSym()
    return TypeVar(Syn(head, sym.syn), sym: sym)
  }


  func parseDash() -> Form {
    let head = getCurrentAndAdvance()
    if atEnd { failParse(token: head, "dangling dash at end of file.") }
    if current.kind != .sym {
      failParse("dash must be followed by numeric literal or symbol.")
      // note: the numeric case is lexed as a number, and not handled here.
    }
    let sym = parseSym()
    return Tag(Syn(head, sym.syn), sym: sym)
  }


  func parseSlash() -> Form {
    let head = getCurrentAndAdvance(requireSpace: false)
    if atEnd { failParse(token: head, "dangling slash at end of file.") }
    let expr: Expr = parseSubForm(subj: "`/` form")
    return Default(Syn(head, expr.syn), expr: expr)
  }


  // MARK: nesting sentences.


  func parseParen() -> Form {
    let head = getCurrentAndAdvance(requireSpace: false)
    let els: [Expr] = parseSubForms(subj: "parenthesized expression")
    return Paren(synForTerminator(head: head, terminator: .parenC, "parenthesized expression"), els: els)
  }


  func parseTypeArgs() -> Form {
    let head = getCurrentAndAdvance(requireSpace: false)
    let exprs: [Expr] = parseSubForms(subj: "type constraint")
    return TypeArgs(synForTerminator(head: head, terminator: .angleC, "type constraint"), exprs: exprs)
  }


  func parseDo() -> Form {
    let head = getCurrentAndAdvance(requireSpace: false)
    let body = parseBody(subj: "`do` form")
    return Do(synForTerminator(head: head, terminator: .braceC, "`do` form"), body: body)
  }


  // MARK: keyword sentences.


  func parseAnd() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let terms: [Expr] = parseSubForms(subj: "`and` form")
    return And(synForSemicolon(head: head, "and"), terms: terms)
  }


  func parseOr() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let terms: [Expr] = parseSubForms(subj: "`or` form")
    return Or(synForSemicolon(head: head, "or"), terms: terms)
  }


  func parseExtensible() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let nameSym: Sym = parseForm(subj: "`extensible` form", exp: "name symbol")
    let constraints: [Expr] = parseSubForms(subj: "extensible type constraints")
    return Extensible(synForSemicolon(head: head, "extensible"), sym: nameSym, constraints: constraints)
  }


  func parseFn() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let sig: Sig = parseForm(subj: "`fn` form", exp: "function signature")
    let body = parseBody(subj: "`fn` form")
    return Fn(synForSemicolon(head: head, "fn"), sig: sig, body: body)
  }


  func parseHostType() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let nameSym: Sym = parseForm(subj: "`host_type` form", exp: "name symbol")
    return HostType(synForSemicolon(head: head, "host_type"), sym: nameSym)
  }


  func parseHostVal() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let typeExpr: Expr = parseSubForm(subj: "`host_val` form")
    let code: LitStr = parseForm(subj: "`host_val` form", exp: "code string")
    let deps: [Identifier] = parseSubForms(subj: "`host_val` form")
    return HostVal(synForSemicolon(head: head, "host_val"), typeExpr: typeExpr, code: code, deps: deps)
  }


  func parseIf() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let clauses: [Clause] = parseSubForms(subj: "`if` form")
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
    return If(synForSemicolon(head: head, "`if` form"), cases: cases, dflt: dflt)
  }


  func parseIn() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let identifier: Identifier = parseSubForm(subj: "`in` form")
    let defs: [Def] = parseSubForms(subj: "`in` form")
    return In(synForSemicolon(head: head, "`in` form"), identifier: identifier, defs: defs)
  }


  func parseMatch() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let expr: Expr = parseSubForm(subj: "`match` form")
    let clauses: [Clause] = parseSubForms(subj: "`match` form")
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
    return Match(synForSemicolon(head: head, "`match` form"), expr: expr, cases: cases, dflt: dflt)
  }


  func parsePub() -> Form {
    let head = getCurrentAndAdvance(requireSpace: true)
    let def: Def = parseSubForm(subj: "`pub` form")
    return Pub(Syn(head, def.syn), def: def)
  }


  // MARK: Helpers.


  func slice(_ pos: Int, _ end: Int) -> String {
    return String(bytes: source.text[pos..<end])!
  }


  func parseSpace() -> Int {
    var end = atEnd ? tokens.last!.end : current.pos
    while !atEnd {
      let k = current.kind
      if !(k == .newline || k == .spaces || k == .comment) { break }
      end = current.end
      advance()
    }
    return end
  }


  func advance() { tokenPos += 1 }


  func getCurrentAndAdvance() -> Token {
    let token = current
    advance()
    return token
  }


  func getCurrentAndAdvance(requireSpace: Bool) -> Token {
    let token = current
    advance()
    if requireSpace {
      let k = current.kind
      if !(k == .newline || k == .spaces || k == .comment || k == .semicolon) {
        failParse(token: token, "form must be followed by a space")
      }
    }
    _ = parseSpace()
    return token
  }


  func failLex(token: Token, _ msg: String) -> Never {
    errZ(source.diagnostic(token: token, msg: "lexical error: " + msg))
    exit(1)
  }


  func failParse(token: Token, _ msg: String) -> Never {
    errZ(source.diagnostic(token: token, msg: "parse error: " + msg))
    exit(1)
  }


  func failParse(_ msg: String) -> Never {
    failParse(token: current, msg)
  }


  func failEnd(_ msg: String) -> Never {
    errZ(source.diagnosticAtEnd(msg: "parse error: " + msg))
    exit(1)
  }
}
