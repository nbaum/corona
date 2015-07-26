#\ -w -o 0.0.0.0 -p 9000

$: << "lib"

require 'corona'
require 'dotenv'

Dotenv.load

use Rack::Reloader, 0
use Rack::Lock

run -> env { Corona::API.new.call(env) }
