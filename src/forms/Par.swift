// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Par: _Form { // parameter.
  
  static func mk(form: Form, _ subj: String) -> Par {
    return Par(form.syn)
  }
}

