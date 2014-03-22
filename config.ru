
require 'corona'

use Rack::Reloader, 0

run -> env { Corona::API.new.call(env) }

