// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


func check(condition: Bool, @autoclosure _ message: () -> String, file: StaticString = __FILE__, line: UWord = __LINE__) {
  if !condition {
    fatalError(message, file: file, line: line)
  }
}
