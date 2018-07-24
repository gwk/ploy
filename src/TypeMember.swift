// Copyright © 2018 George King. Permission to use this file is granted in ploy/license.txt.


enum TypeMember {
  case posField(Type)
  case labField(TypeLabField)
  case variant(TypeVariant)
}


func posFieldHostName(index: Int) -> String { return "_\(index)" }
