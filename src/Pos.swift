// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct Pos: CustomStringConvertible {
  let idx: String.CharacterView.Index
  let line: Int
  let col: Int

  var description: String { return "Pos(\(idx), \(line), \(col))" }
}
