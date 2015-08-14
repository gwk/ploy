// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class TypeVal: Hashable {
  var hashValue: Int { return ObjectIdentifier(self).hashValue }
}

func ==(l: TypeVal, r: TypeVal) -> Bool { return l === r }

