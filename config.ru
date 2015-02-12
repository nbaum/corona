#\ -w -p 9000

$: << "lib"

require 'corona'
require 'dotenv'

Dotenv.load

use Rack::Reloader, 0

run -> env { Corona::API.new.call(env) }
