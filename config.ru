# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

require "English"
$LOAD_PATH << "lib"

require "corona"
require "dotenv"

Dotenv.load

Thread.abort_on_exception = true

use Rack::Reloader, 0
use Rack::Lock

run -> env { Corona::API.new.call(env) }
