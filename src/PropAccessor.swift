// © 2017 George King. Permission to use this file is granted in ploy/license.txt.


enum PropAccessor {
  case index(Int)
  case name(String)

  var accessorString: String {
    switch self {
    case .index(let index): return String(index)
    case .name(let string): return string
    }
  }
}
