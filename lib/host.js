// Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

function _raise(msg) {
  throw msg
}

// in FS.
let FS__write_Bool  = function($) { HOST__fs.writeSync($._0, $._1); return {}; }
let FS__write_Int   = function($) { HOST__fs.writeSync($._0, $._1); return {}; }
let FS__write_Str   = function($) { HOST__fs.writeSync($._0, $._1); return {}; }

// in ROOT.

let ROOT__true = true;
let ROOT__false = false;

function ROOT__dec_Int($) { return { v: $ - 1 }; }
function ROOT__inc_Int($) { return { v: $ + 1 }; }

function ROOT__add_Int($) { return { v: $._0 + $._1 }; }
function ROOT__sub_Int($) { return { v: $._0 - $._1 }; }
function ROOT__mul_Int($) { return { v: $._0 * $._1 }; }
function ROOT__div_Int($) { return { v: $._0 / $._1 }; }

function ROOT__mod_Int($) {
  let dividend = $._0;
  let divisor = $._1;
  return { v: ((dividend % divisor) + divisor) % divisor };
}

function ROOT__rem_Int($) { return { v: $._0 % $._1 }; }

function ROOT__eq_Int($) { return { v: $._0 == $._1 }; }
function ROOT__ne_Int($) { return { v: $._0 != $._1 }; }
function ROOT__ge_Int($) { return { v: $._0 >= $._1 }; }
function ROOT__gt_Int($) { return { v: $._0 >  $._1 }; }
function ROOT__le_Int($) { return { v: $._0 <= $._1 }; }
function ROOT__lt_Int($) { return { v: $._0 <  $._1 }; }


function ROOT__errL_Bool($) {
  FS__write_Bool({ _0: PROC__std_err, _1: $});
  FS__write_Str({ _0: PROC__std_err, _1: "\n" });
  return {};
}

function ROOT__errL_Int($)  {
  FS__write_Int({ _0: PROC__std_err, _1: $}); 
  FS__write_Str({ _0: PROC__std_err, _1: "\n" });
  return {};
}

function ROOT__errL_Str($)  {
  FS__write_Str({ _0: PROC__std_err, _1: $}); 
  FS__write_Str({ _0: PROC__std_err, _1: "\n" });
  return {};
}

// in HOST.
let HOST__fs = require('fs');
let HOST__process = process

// in PROC.
let PROC__exit = function($) { HOST__process.exit($); return {}; }
let PROC__std_out = HOST__process.stdout.fd
let PROC__std_err = HOST__process.stderr.fd

// TODO: these are probably the wrong type;
// need to repackaged into proper ploy types or hidden behind accessor functions.
//const PROC__cmd   = HOST__process.argv
//const PROC__args  = HOST__process.argv.slice(1)
