// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


struct Pos: CustomStringConvertible {
  let idx: Int
  let line: Int
  let col: Int
  
  var description: String { return "Pos(\(idx), \(line), \(col))" }
  
  func adv(dist: Int = 1) -> Pos { return Pos(idx: idx + 1, line: line, col: col) }
  
  func advLine() -> Pos { return Pos(idx: idx + 1, line: line + 1, col: 0) }
  
  func dist(end: Pos) -> Int { return end.idx - idx }
}
