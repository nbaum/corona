# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

require 'shellwords'

module Corona

  class API

    attr_reader :params

    def call (env)
      @request = Rack::Request.new(env)
      @response = Rack::Response.new
      dispatch
    end

    def do_list_volumes
      Volume.list(params[:pool]).map do |v|
        {
          name: v.name,
          pool: v.pool,
          size: v.size,
        }
      end
    end

    def do_log
      instance.log
    end

    def do_start
      instance.config = params[:config]
      instance.start
      true
    end

    def do_pause
      instance.pause
      true
    end

    def do_unpause
      instance.unpause
      true
    end

    def do_stop
      i = instance
      i.stop
      Timeout.timeout 5 do
        sleep 0.1 while i.running?
        return true
      end
    rescue
      i.kill
    end

    def do_status
      instance.status
    end

    def do_clone
      instance(:new_instance).clone(instance)
      true
    end

    def do_reset
      instance.qmp(:system_reset)
    end

    def do_qmp
      instance.qmp(params[:execute], params[:arguments])
    end

    def do_qga
      instance.qga(params[:execute], params[:arguments])
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

    def do_migrate_status
      instance.migrate_status
    end

    def do_migrate_wait
      instance.migrate_wait
    end

    def do_migrate_cancel
      instance.migrate_cancel
    end

    def do_realize
      if base = params[:base]
        Volume.new(params[:path], params[:pool])
          .clone(Volume.new(base[:path], base[:pool]))
      elsif url = params[:url]
        name = params[:path].shellescape
        Tempfile.open("realize", "/mnt/data/") do |f|
          system "wget -O #{f.path.shellescape} #{url.shellescape}"
          size = File.stat(f.path).size
          system "dog vdi create #{name} #{size}"
          system "cat #{f.path.shellescape} | dog vdi write #{name}"
        end
      else
        Volume.new(params[:path], params[:pool]).truncate(params[:size])
      end
    end

    def do_delete
      Volume.new(params[:path], params[:pool]).remove
    end

    def do_resize
      Volume.new(params[:path], params[:pool]).resize(params[:size])
    end

    def do_wipe
      Volume.new(params[:path], params[:pool]).wipe
    end

    def do_space_used
      Volume.new(params[:path], params[:pool]).used
    end

    private

    def instance (param = :instance)
      Instance[params[param]]
    end

    def dispatch
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
