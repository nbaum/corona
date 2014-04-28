
module Corona
  
  class API
    
    attr_reader :params
    
    def call (env)
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      dispatch
    end
    
    def do_iso_list ()
      Volume.list("isoimages").map{|v|File.basename(v.path)}
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
    
    def do_clone ()
      instance(:new_instance).clone(instance)
    end
    
    private
    
    def instance (param = :instance)
      Instance[params[param]]
    end
    
    def dispatch ()
      @params = YAML.load(@request.body.read)
      name = @request.path[1..-1]
      res = __send__("do_" + name)
      @response.write res.to_yaml
      @response.finish
    rescue Exception => e
      @response.write [e.message, e.backtrace].to_yaml
      @response.status = 500
      @response.finish
    end
    
  end
  
end

