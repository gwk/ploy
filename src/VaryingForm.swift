// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


protocol VaryingForm: Form {
  // Enum Form.
  // Adopters must implement `expDesc`, `accept`.
}

extension VaryingForm {

  var syn: Syn { return actForm.syn }

  // CustomStringConvertible.

  var description: String { return "\(type(of: self)):\(actForm.description)" }

  var textTreeChildren: [Any] { return actForm.textTreeChildren }
}
