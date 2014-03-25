
require 'corona/errors'
require 'corona/monkey'
require 'corona/watcher'

require 'securerandom'
require 'shellwords'
require 'fileutils'
require 'extlib'

module Corona
  
  class Task
    
    def self.path (extra = "")
      File.join("var", name.split("::")[-1].downcase.pluralize, extra)
    end
    
    def command
      raise NotImplementedError
    end
    
    def initialize (id = "t" + SecureRandom.hex(4))
      super()
      @id = id
      watch if pid
    end
    
    def pid
      File.read(path("pid")).to_i
    rescue Errno::ENOENT
      nil
    end
    
    def start
      raise Error, "Task already running" if running?
      spawn command
    end
   
    def stop
      raise Error, "Task not running" if !running?
      Process.kill :KILL, pid
    end
    
    def running?
      pid && File.exist?("/proc/#{pid}")
    end
    
    def path (extra = "")
      self.class.path(File.join("#{@id}", extra))
    end
    
    def cleanup
      FileUtils.rm_f(path("pid"))
    end
    
    def log
      File.read(path("log")) rescue nil
    end
    
    private
    
    def mkpath (extra = "")
      FileUtils.mkpath(path(extra))
    end
    
    def spawn (command)
      synchronous_fork do
        begin
          mkpath
          File.write(path("pid"), $$.to_s)
          log = path("log")
          Kernel.exec(command.shelljoin, :in => :close, [:out, :err] => [log, "w"])
        ensure
          cleanup
        end
      end
      watch
    end
    
    def watch
      Watcher.watch(self)
    end
    
  end
  
end

