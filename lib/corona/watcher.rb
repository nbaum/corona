
require 'singleton'
require 'rb-inotify'

module Corona
  
  class Watcher
    include Singleton
    
    def self.watch (task)
      instance.watch(task)
    end
    
    def initialize
      @notifier = INotify::Notifier.new
      Thread.new do
        @notifier.run
      end
    end
    
    def watch (task)
      if task.running?
        @notifier.watch("/proc/#{task.pid}/exe", :close_nowrite) do
          task.cleanup unless task.running?
        end
      else
        task.cleanup
      end
    end
    
  end
  
end

