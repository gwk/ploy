// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Darwin


typealias PloyToken = Token<TokenKind>


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
  let tokens: [PloyToken]
  var tokenPos: Int = 0

  init(source: Source) {
    self.source = source
    self.tokens = Array(Lexer(source: source))
  }

  var atEnd: Bool { return tokenPos == tokens.count }
  var current: PloyToken { return tokens[tokenPos] }


  func parse() -> [Def] {
    if tokens.isEmpty { return [] }
    let defs: [Def] = parseForms(subj: "top level")
    if !atEnd { failParse("unexpected terminator token: \(current.kind)") }
    return defs
  }


  func parseActForm(allowSpaces: Bool = true) -> ActForm {
    return parsePhrase(precedence: (allowSpaces ? 0 : Parser.unspacedPrecedence))
  }


  func parseForm<F: Form>(subj: String, exp: String? = nil, allowSpaces: Bool = true) -> F {
    return F.expect(parseActForm(allowSpaces: allowSpaces), subj: subj, exp: exp)
  }


  func parseForms<F: Form>(subj: String) -> [F] {
    _ = parseSpace()
    var prevSpace = true
    var subForms: [F] = []
    while !atEnd {
      if Parser.terminators.contains(current.kind) {
        break
      }
      if !prevSpace {
        failParse("adjacent forms require a separating space.")
      }
      let form: F = parseForm(subj: subj)
      subForms.append(form)
      prevSpace = form.syn.hasEndSpace
    }
    return subForms
  }

  static let terminators: Set<TokenKind> = [.semicolon, .parenC, .braceC, .brackC, .angleC]


  func parseFormsAndFinalForm<F0: Form, F1: Form>(subj: String) -> ([F0], F1?) {
    _ = parseSpace()
    var prevSpace = true
    var forms: [F0] = []
    var finalForm: F1? = nil
    while !atEnd {
      if Parser.terminators.contains(current.kind) {
        break
      }
      if !prevSpace {
        failParse("adjacent forms require a separating space.")
      }
      let actForm = parseActForm()
      if let finalForm = finalForm {
        actForm.failSyntax("\(subj) expected `;`; received subsequent \(actForm.actDesc)", // Note: assumes the expected terminator.
          notes: (finalForm, "final \(finalForm.actDesc) is here."))
      }
      if let form = F0.accept(actForm) { forms.append(form) }
      else if let form = F1.accept(actForm) { finalForm = form }
      else {
        actForm.failSyntax("\(subj) expected \(F0.expDesc) or final \(F1.expDesc); received \(actForm.actDesc).")
      }
      prevSpace = actForm.syn.hasEndSpace
    }
    return (forms, finalForm)
  }


  func parseBody(subj: String) -> Body {
    let exprs: [Expr] = parseForms(subj: "body")
    if atEnd { failEnd("\(subj) reached end of file.") }
    let syn: Syn
    if let hd = exprs.first?.syn, let tl = exprs.last?.syn {
      syn = Syn(hd, tl)
    } else {
      syn = Syn(source: source, lineIdx: current.lineIdx, linePos: current.linePos, pos: current.pos, visEnd: current.pos, end: current.pos)
    }
    return Body(syn, exprs: exprs)
  }


  func parsePhrase(precedence: Int) -> ActForm {
    if atEnd { failEnd("reached end of file.") }
    var left = parsePoly()
    overLeft: while !atEnd {
      let leftSpace = left.syn.hasEndSpace
      for i in precedence..<Parser.opPrecedenceGroups.count {
        let group = Parser.opPrecedenceGroups[i]
        let expSpace = (i < Parser.unspacedPrecedence)
        for (kind, handler) in group {
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
            continue overLeft
          }
        }
      }
      // adjacency operators have highest precedence.
      if !leftSpace {
        for (kind, handler) in Parser.adjacencyOperators {
          if current.kind == kind {
            let right = parsePhrase(precedence: Parser.opPrecedenceGroups.count) // TODO: decide if this should call parsePoly instead.
            left = handler(left, right)
            continue overLeft
          }
        }
      }
      break
    }
    return left
  }

  static let opGroups: [[(TokenKind, (ActForm, ActForm)->ActForm)]] = [
    [ (.typeAlias, TypeAlias.mk),
      (.bind, Bind.mk),
      (.extension_, Extension.mk),
      (.case_, Case.mk)],
    [ (.union, Union.mk)],
    [ (.intersect, Intersect.mk)],
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

  static let adjacencyOperators: [(TokenKind, (ActForm, ActForm)->ActForm)] = [
    (.parenO, CallAdj.mk),
    (.angleO, Reif.mk),
  ]


  func parsePoly() -> ActForm {
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


  func parseSymOrPath() -> ActForm {
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
    let r = token.range
    let p0 = r.lowerBound
    let leadUnderscore = (source.text[p0] == "_")
    var prevUnderscore = false
    var trailingDigits = -1
    for pos in token.range {
      let byte = source.text[pos]
      if byte == "_" {
        if prevUnderscore {
          failLex(token: token, pos: pos, "symbols cannot contain repeated '_' characters.")
        } else {
          prevUnderscore = true
        }
      } else {
        prevUnderscore = false
        if byte >= "0" && byte <= "9" {
          if trailingDigits < 0 {
            trailingDigits = pos
          }
        } else {
          trailingDigits = -1
        }
      }
    }
    if leadUnderscore && trailingDigits == p0+1 {
      failLex(token: token, "symbols cannot consist of an underscore followed by digits.")
    }
    return Sym(Syn(source: source, token: token, end: parseSpace()), name: slice(token.pos, token.end))
  }


  func parseLitNum() -> LitNum {
    do {
      let val = try source.parseSignedNumber(token: current)
      let token = getCurrentAndAdvance()
      return LitNum(Syn(source: source, token: token, end: parseSpace()), val: Int(val))
    } catch let e as PloyToken.Err {
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


  func synForTerminator(head: PloyToken, terminator: TokenKind, _ subj: String) -> Syn {
    if atEnd {
      failParse(token: head, "\(subj) expected \(terminator) terminator; reached end of file.")
      // TODO: report correct position.
    }
    if current.kind != terminator {
      failParse("\(subj) expected \(terminator) terminator; received `\(current.kind)`.")
    }
    let visEnd = current.end
    advance()
    return Syn(source: source, token: head, visEnd: visEnd, end: parseSpace())
  }


  func synForSemicolon(head: PloyToken, _ subj: String) -> Syn {
    return synForTerminator(head: head, terminator: .semicolon, subj)
  }


  // MARK: prefixes.


  func parseBling() -> ActForm {
    let head = getCurrentAndAdvance()
    return Sym(Syn(source: source, token: head, end: parseSpace()), name: "$")
  }


  func parseCaret() -> ActForm {
    let head = getCurrentAndAdvance()
    if atEnd { failParse(token: head, "dangling caret at end of file.") }
    if current.kind != .sym {
      failParse("caret must be followed by a symbol.")
    }
    let sym = parseSym()
    return TypeVar(Syn(head, sym.syn), sym: sym)
  }


  func parseDash() -> ActForm {
    let head = getCurrentAndAdvance()
    if atEnd { failParse(token: head, "dangling dash at end of file.") }
    if current.kind != .sym {
      failParse("dash must be followed by numeric literal or symbol.")
      // note: the numeric case is lexed as a number, and not handled here.
    }
    let sym = parseSym()
    return Tag(Syn(head, sym.syn), sym: sym)
  }


  func parseSlash() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: false)
    if atEnd { failParse(token: head, "dangling slash at end of file.") }
    let expr: Expr = parseForm(subj: "`/` form")
    return Default(Syn(head, expr.syn), expr: expr)
  }


  // MARK: nesting sentences.


  func parseParen() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: false)
    let els: [Expr] = parseForms(subj: Paren.expDesc)
    return Paren(synForTerminator(head: head, terminator: .parenC, Paren.expDesc), els: els)
  }


  func parseTypeArgs() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: false)
    let exprs: [Expr] = parseForms(subj: TypeArgs.expDesc)
    return TypeArgs(synForTerminator(head: head, terminator: .angleC, TypeArgs.expDesc), exprs: exprs)
  }


  func parseDo() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: false)
    let body = parseBody(subj: Do.expDesc)
    return Do(synForTerminator(head: head, terminator: .braceC, Do.expDesc), body: body)
  }


  // MARK: keyword sentences.


  func parseAnd() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let terms: [Expr] = parseForms(subj: "`and` form")
    return And(synForSemicolon(head: head, "and"), terms: terms)
  }


  func parseOr() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let terms: [Expr] = parseForms(subj: "`or` form")
    return Or(synForSemicolon(head: head, "or"), terms: terms)
  }


  func parseExtensible() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let nameSym: Sym = parseForm(subj: "`extensible` form", exp: "name symbol")
    let constraints: [Expr] = parseForms(subj: "extensible type constraints")
    return Extensible(synForSemicolon(head: head, "extensible"), sym: nameSym, constraints: constraints)
  }


  func parseFn() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let sig: Sig = parseForm(subj: "`fn` form", exp: "function signature")
    let body = parseBody(subj: "`fn` form")
    return Fn(synForSemicolon(head: head, "fn"), sig: sig, body: body)
  }

  func parseHostFn() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let sig: Sig = parseForm(subj: "`fn` form", exp: "function signature")
    let body = parseBody(subj: "`fn` form")
    return Fn(synForSemicolon(head: head, "fn"), sig: sig, body: body)
  }

  func parseHostType() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let nameSym: Sym = parseForm(subj: "`host_type` form", exp: "name symbol")
    return HostType(synForSemicolon(head: head, "host_type"), sym: nameSym)
  }


  func parseHostVal() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let typeExpr: Expr = parseForm(subj: "`host_val` form")
    let (deps, code): ([Identifier], LitStr?) = parseFormsAndFinalForm(subj: "`host_val` form")
    if let code = code {
      return HostVal(synForSemicolon(head: head, "host_val"), typeExpr: typeExpr, code: code, deps: deps)
    } else {
      failParse("`host_val` form expected final code string.")
    }
  }


  func parseIf() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let (cases, dflt): ([Case], Default?) = parseFormsAndFinalForm(subj: "`if` form")
    return If(synForSemicolon(head: head, "`if` form"), cases: cases, dflt: dflt)
  }


  func parseIn() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let identifier: Identifier = parseForm(subj: "`in` form")
    let defs: [Def] = parseForms(subj: "`in` form")
    return In(synForSemicolon(head: head, "`in` form"), identifier: identifier, defs: defs)
  }


  func parseMatch() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let expr: Expr = parseForm(subj: "`match` form")
    let (cases, dflt): ([Case], Default?) = parseFormsAndFinalForm(subj: "`if` form")
    return Match(synForSemicolon(head: head, "`match` form"), expr: expr, cases: cases, dflt: dflt)
  }


  func parsePub() -> ActForm {
    let head = getCurrentAndAdvance(requireSpace: true)
    let def: Def = parseForm(subj: "`pub` form")
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


  func getCurrentAndAdvance() -> PloyToken {
    let token = current
    advance()
    return token
  }


  func getCurrentAndAdvance(requireSpace: Bool) -> PloyToken {
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


  func failLex(token: PloyToken, pos: Int? = nil, _ msg: String) -> Never {
    errZ(source.diagnostic(token: token, pos: pos, msg: "lexical error: " + msg))
    exit(1)
  }


  func failParse(token: PloyToken, _ msg: String) -> Never {
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
