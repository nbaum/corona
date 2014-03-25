
module Corona
  
  class API
    
    attr_reader :params
    
    def call (env)
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      dispatch
    end
    
    def do_log ()
      instance.log
    end
    
    def do_stop ()
      i = instance
      i.stop
      sleep 0.1 while i.running?
      true
    end
    
    def do_start ()
      instance.config = params[:config]
      instance.start
      true
    end
    
    def do_status ()
      instance.status
    end
    
    private
    
    def instance
      Instance[params[:instance]]
    end
    
    def dispatch ()
      @params = YAML.load(@request.body.read)
      name = @request.path[1..-1]
      res = __send__("do_" + name)
      @response.write res.to_yaml
      @response.finish
    rescue => e
      @response.write [e.message, e.backtrace].to_yaml
      @response.status = 500
      @response.finish
    end
    
  end
  
end

