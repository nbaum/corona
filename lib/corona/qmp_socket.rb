
require 'socket'
require 'json'

module Corona
  
  class QmpSocket < UNIXSocket
    
    def initialize instance
      super(instance.path("qmp"))
      readline
      @id = 0
      @instance = instance
      @tickets = {}
      Thread.new do
        begin
          while true
            v = JSON.parse readline
            ticket = @tickets[v["id"]] if v["id"]
            if r = v["return"]
              ticket.push [r, nil] if ticket
            elsif e = v["error"]
              ticket.push [nil, e] if ticket
            else
              instance.event(v) rescue nil
            end
          end
        end
      end
      execute("qmp_capabilities")
    end
    
    def execute (command, args = {})
      @tickets[@id += 1] = q = Queue.new
      puts({"execute" => command, "arguments" => args, "id" => @id}.to_json)
      r, e = q.pop
      r || raise(Error, "#{e["class"]}: #{e["desc"]}: #{e["data"]}")
    end
    
  end
  
end

