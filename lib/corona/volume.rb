# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

require "corona/errors"
require "fileutils"

module Corona

  class Volume

    attr_accessor :name, :pool

    def self.path (*parts)
      File.join(*parts)
    end

    def self.list (pool)
      list = []
      dog("vdi", "list", "-r").split("\n").each do |row|
        thepool, name = row.split(" ")[1].split("/")
        next unless name
        next unless pool == thepool
        list << new(name, pool)
      end
      list
    end

    def initialize (name, pool = nil)
      @pool = pool
      @name = name
    end

    def path (*parts)
      @pool ? self.class.path(@pool, @name, *parts) : self.class.path(@name, *parts)
    end

    def truncate (size)
      if exist?
        dog "vdi", "resize", path, size
      else
      end
    end

    def clone_command (source)
      fail "Unimplemented"
    end

    def clone (source)
      dog "vdi", "delete", "-s", "clone", source.path
      dog "vdi", "snapshot", "-s", "clone", source.path
      dog "vdi", "clone", "-s", "clone", source.path, path
      dog "vdi", "delete", "-s", "clone", source.path
    end

    def remove
      dog "vdi", "delete", path
    end

    def size
      dog("vdi", "list", "-r", path).split(" ")[3].to_i
    end

    def wipe
      size_was = size
      dog "vdi", "delete", path
      truncate size_was
    end

    def qemu_url
      "sheepdog:///#{path}"
    end

    private

    class ExecuteError < Exception
    end

    def exist?
      dog "vdi", "check", "-e", path
      return true
    rescue
      return false
    end

    def self.sh (*args)
      output = IO.popen(args.map(&:to_s).shelljoin, "r", err: [:child, :out]) do |io|
        io.read
      end
      if $?.success?
        output
      else
        fail output
      end
    end

    def self.dog (*args)
      sh "dog", *args
    end

    def dog (*args)
      self.class.dog(*args)
    end

    def sh (*args)
      self.class.sh(*args)
    end

  end

end
