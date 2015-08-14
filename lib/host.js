// Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

const PLOY_HOST__fs = require('fs');
const PLOY_HOST__process = process

// TODO: these are probably the wrong type;
// need to repackaged into proper ploy types or hidden behind accessor functions.
const PLOY_HOST__cmd = PLOY_HOST__process.argv
const PLOY_HOST__args = PLOY_HOST__process.argv.slice(1)

const PLOY_HOST__std_out = PLOY_HOST__process.stdout.fd
const PLOY_HOST__std_err = PLOY_HOST__process.stderr.fd

const PLOY_HOST__exit = function($) { PLOY_HOST__process.exit($) }

const PLOY_HOST__write_Str = function($) { PLOY_HOST__fs.writeSync($.file, $.str) }
const PLOY_HOST__write_Int = function($) { PLOY_HOST__fs.writeSync($.file, $.str) }
const PLOY_HOST__write_Bool = function($) { PLOY_HOST__fs.writeSync($.file, $.bool) }
