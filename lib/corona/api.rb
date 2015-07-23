
module Corona
  
  class API
    
    attr_reader :params
    
    def call (env)
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      dispatch
    end
    
    def do_list_volumes ()
      Volume.list(params[:pool]).map do |v|
        {
          name: v.name,
          pool: v.pool,
          size: v.size
        }
      end
    end
    
    def do_log ()
      instance.log
    end
    
    def do_start ()
      instance.config = params[:config]
      instance.start
      true
    end
    
    def do_pause ()
      instance.pause
      true
    end

    def do_unpause ()
      instance.unpause
      true
    end

    def do_stop ()
      i = instance
      i.stop
      sleep 0.1 while i.running?
      true
    end
    
    def do_status ()
      instance.status
    end
    
    def do_clone ()
      instance(:new_instance).clone(instance)
      true
    end
    
    def do_reset
      instance.qmp(:system_reset)
    end
    
    def do_command
      instance.command
    end
    
    def do_suspend
      instance.migrate_to(params[:tag])
      true
    end
    
    def do_resume
      instance.config = params[:config]
      instance.migrate_from(params[:tag])
      true
    end

    def do_migrate_to
      instance.config = params[:config]
      instance.migrate_to(params[:host], params[:port])
      true
    end

    def do_migrate_from
      instance.config = params[:config]
      instance.migrate_from(params[:host], params[:port])
      true
    end

    def do_realize ()
      if base = params[:base]
        Volume.new(params[:path], params[:pool]).
            clone(Volume.new(base[:path], base[:pool]))
      else
        Volume.new(params[:path], params[:pool]).truncate(params[:size])
      end
    end
    
    def do_delete ()
      Volume.new(params[:path], params[:pool]).remove
    end
  
    def do_wipe
      Volume.new(params[:path], params[:pool]).wipe
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
    rescue => e
      puts e.message
      puts e.backtrace
      @response.write [e.class.name, e.message, e.backtrace[0...(e.backtrace.length - caller.length)]].to_yaml
      @response.status = 500
      @response.finish
    end
    
  end
  
end

