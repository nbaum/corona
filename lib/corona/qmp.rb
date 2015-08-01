# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

require "socket"
require "json"

module Corona

  class QMP

    def initialize (io)
      readline
      @id = 0
      @tickets = {}
      @io = io
      start_thread
    end

    def process (message)
      v = JSON.parse(message)
      ticket = @tickets[v["id"]]
      if !ticket
        return
      elsif res = v["return"]
        ticket.push [true, res]
      elsif err = v["error"]
        ticket.push [false, err]
      end
    end

    def start_thread
      Thread.new do
        loop do
          begin
            process @io.readline
          rescue EOFError
            break
          end
        end
      end
      execute("qmp_capabilities")
    end

    def execute (command, args = {})
      @tickets[@id += 1] = q = Queue.new
      message = {
        id: @id,
        execute: command,
        arguments: args,
      }
      @io.puts message.to_json
      won, value = q.pop
      won ? value : fail(Error, "#{value['class']}: #{value['desc']}: #{value['data']}")
    end

  end

end
