
module Corona
  
  class API
    
    def call (env)
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      dispatch
    end
    
    def dispatch
      args = YAML.load(@request.body.read)
      name = @request.path[1..-1]
      res = __send__("do_" + name, args)
      @response.write res.to_yaml
      @response.finish
    rescue => e
      @response.write [e.message, e.backtrace].to_yaml
      @response.status = 500
      @response.finish
    end
    
    def do_log (instance: nil)
      Instance[instance].log
    end
    
    def do_stop (instance: nil)
      i = Instance[instance]
      i.stop
      sleep 0.1 while i.running?
      true
    end
    
    def do_start (instance: nil, config: nil)
      Instance[instance].config = config
      Instance[instance].start
      true
    end
    
    def do_status (instance: nil)
      Instance[instance].status
    end
    
  end
  
end

