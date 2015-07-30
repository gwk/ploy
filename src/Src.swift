// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


typealias CharString = Array<Character>

struct Src: CustomStringConvertible {
  let path: String
  let text: CharString
  
  var description: String { return "Src(\(path))" }
  
  init(path: String) {
    self.path = path
    self.text = CharString(InFile(path: path).read().characters)
  }
}
