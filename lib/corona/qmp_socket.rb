Thread.abort_on_exception = true

require 'socket'
require 'json'

module Corona

  class QmpSocket < UNIXSocket

    def initialize (path)
      super(path)
      readline
      @id, @tickets = 0, {}
      Thread.new do
        loop do
          v = JSON.parse(readline)
          if ticket = @tickets[v["id"]]
            if res = v["return"]
              ticket.push [true, res]
            elsif err = v["error"]
              ticket.push [false, err]
            end
          end
        end
      end
      execute("qmp_capabilities")
    end

    def execute (command, args = {})
      @tickets[@id += 1] = q = Queue.new
      puts({"execute" => command, "arguments" => args, "id" => @id}.to_json)
      won, value = q.pop
      won ? value : raise(Error, "#{e["class"]}: #{e["desc"]}: #{e["data"]}")
    end

  end

end

