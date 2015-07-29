// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


for (i, arg) in Process.arguments.enumerate() {
  if i > 0 {
    let src = InFile(path: arg).read()
    errL(src)
  }
}
