# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

require "socket"
require "json"

module Corona

  class QGA

    def initialize (io)
      @io = io
      @io.set_encoding "BINARY"
      @responses = Queue.new
      start_thread
    end

    def close
      @io.close
    end

    def process (message)
      v = JSON.parse(message)
      if res = v["return"]
        @responses.push [true, res]
      elsif err = v["error"]
        @responses.push [false, err]
      end
    rescue Exception => e
    end

    def reset
      @io.puts({execute: "guest-sync-delimited", arguments: {id: 42}}.to_json)
      while @io.getbyte != 0xff; end
      @io.readline
    end

    def start_thread
      reset
      Thread.new do
        loop do
          begin
            process @io.readline
          rescue EOFError
            break
          end
        end
      end
    end

    def execute (command, args = {})
      message = {
        execute: command,
        arguments: args,
      }
      message.delete(:id)
      @io.puts message.to_json
      won, value = @responses.pop
      won ? value : fail(Error, "#{value['class']}: #{value['desc']}: #{value['data']}")
    end

  end

end
