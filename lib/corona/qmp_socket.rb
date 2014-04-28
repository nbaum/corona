
require 'socket'
require 'json'

module Corona
  
  class QmpSocket < UNIXSocket
    
    def initialize (path)
      super(path)
      readline
      @id = 0
      @tickets = {}
      Thread.new do
        begin
          while true
            line = readline
            v = JSON.parse line
            ::Kernel.puts "< #{line}"
            ticket = @tickets[v["id"]] if v["id"]
            if r = v["return"]
              ticket.push [r, nil] if ticket
            elsif e = v["error"]
              ticket.push [nil, e] if ticket
            else
              #instance.event(v) rescue nil
            end
          end
        end
      end
      execute("qmp_capabilities")
    end
    
    def execute (command, args = {})
      @tickets[@id += 1] = q = Queue.new
      message = {"execute" => command, "arguments" => args, "id" => @id}.to_json
      ::Kernel.puts "> #{message}"
      puts message
      r, e = q.pop
      if e
        raise(Error, "#{e["class"]}: #{e["desc"]}: #{e["data"]}")
      else
        r
      end 
    end
    
  end
  
end

