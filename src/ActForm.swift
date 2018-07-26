// Copyright © 2018 George King. Permission to use this file is granted in ploy/license.txt.


protocol ActForm: Form {
  // Some actual syntax form. Adopted by each specific Form type.
  // Adopters must implement `expDesc`, `accept`, `syn`, `textTreeChildren`.
}


extension ActForm {

  // Form.

  var actForm: ActForm { return self }

  static func accept(_ actForm: ActForm) -> Self? { return actForm as? Self }
}


class ActFormBase: Hashable {
  // Distinct from ActForm so that generic `accept` works,
  // and so that we can implement `Hashable` without the dreaded `associated type` protocol restrictions.
  let syn: Syn

  init(_ syn: Syn) { self.syn = syn }

  // CustomStringConvertible.

  var description: String { return "\(type(of: self)):\(syn)" }

  // Hashable.

  static func ==(l: ActFormBase, r: ActFormBase) -> Bool { return l === r }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }
}
