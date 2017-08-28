// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Syn: CustomStringConvertible {

  let source: Source
  let lineIdx: Int // 0-based index of the first line.
  let linePos: Int // position of the start of the form's first line.
  let pos: Int
  let visEnd: Int // position past the last visible character.
  let end: Int // position past the last member character, including whitespace.

  var colIdx: Int { return pos - linePos }
  var hasEndSpace: Bool { return visEnd < end }
  var visRange: Range<Int> { return pos..<visEnd }
  var range: Range<Int> { return pos..<end }

  init(source: Source, lineIdx: Int, linePos: Int, pos: Int, visEnd: Int, end: Int) {
    self.source = source
    self.lineIdx = lineIdx
    self.linePos = linePos
    self.pos = pos
    self.visEnd = visEnd
    self.end = end
    assert(pos <= visEnd, "Syn visEnd is invalid: \(self)")
    assert(visEnd <= end, "Syn end is invalid: \(self)")
  }

  convenience init(source: Source, token: Token, visEnd: Int? = nil, end: Int) {
    self.init(source: source, lineIdx: token.lineIdx, linePos: token.linePos, pos: token.pos, visEnd: visEnd ?? token.end, end: end)
  }

  convenience init(_ l: Token, _ r: Syn) {
    self.init(source: r.source, lineIdx: l.lineIdx, linePos: l.linePos, pos: l.pos, visEnd: r.visEnd, end: r.end)
  }

  convenience init(_ l: Syn, _ r: Syn) {
    self.init(source: l.source, lineIdx: l.lineIdx, linePos: l.linePos, pos: l.pos, visEnd: r.visEnd, end: r.end)
  }

  var description: String {
    return "\(source.name.withoutPathDir.withoutPathExt):\(lineIdx):\(colIdx)(pos:\(pos) visEnd:\(visEnd) end:\(end))"
  }

  func errDiagnostic(prefix: String, msg: String) {
    errZ(source.diagnostic(pos: pos, end: visEnd, linePos: linePos, lineIdx: lineIdx, msg: "\(prefix): \(msg)"))
  }
}
