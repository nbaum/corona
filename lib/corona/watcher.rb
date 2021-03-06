# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

require "singleton"
require "rb-inotify"

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
          sleep 0.1
          watch task
        end
      else
        task.cleanup
      end
    end

  end

end
