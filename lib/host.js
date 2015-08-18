// Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

const _host__fs = require('fs');
const _host__process = process

// TODO: these are probably the wrong type;
// need to repackaged into proper ploy types or hidden behind accessor functions.
const _host__cmd = _host__process.argv
const _host__args = _host__process.argv.slice(1)

const std_out = _host__process.stdout.fd
const std_err = _host__process.stderr.fd

const exit = function($) {
  // TODO: for browser js, log to console and raise exception.
  _host__process.exit($)
}

//const write_Str = function($) { _host__fs.writeSync($.file, $.str) }
//const write_Int = function($) { _host__fs.writeSync($.file, $.str) }
//const write_Bool = function($) { _host__fs.writeSync($.file, $.bool) }
