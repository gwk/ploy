// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class GlobalCtx {
  let mainPath: String
  let file: OutFile
  var conversions: Set<String> = [] // this should be (Type, Type) but tuples do not hash.

  init(mainPath: String, file: OutFile) {
    self.mainPath = mainPath
    self.file = file
  }
}

