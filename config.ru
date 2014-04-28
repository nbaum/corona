#\ -w -o 127.0.0.1

$: << "lib"

require 'corona'

use Rack::Reloader, 0

run -> env { Corona::API.new.call(env) }

