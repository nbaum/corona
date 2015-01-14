
require 'corona/errors'
require 'fileutils'

module Corona

  class Volume
    
    attr_accessor :name, :pool
    
    def self.root (*parts)
      File.join(File.expand_path("var/storage"), *parts)
    end
    
    def self.list (pool)
      Dir.chdir(root(pool)) do
        Dir["**/*"].select do |name|
          File.file?(name)
        end.map do |name|
          new(name, pool)
        end
      end
    end
    
    def self.create (name, pool)
      v = new(name, pool)
      raise Error, "#{path} already exists" if v.exist?
      v
    end
    
    def self.open (name, pool)
      v = new(name, pool)
      raise Error, "#{path} doesn't exist" unless v.exist?
      v
    end
    
    def initialize (name, pool = nil)
      @pool = pool
      @name = name
    end
    
    def path
      File.join(File.expand_path("var/storage"), @pool || "", @name)
    end
    
    def exist? ()
      File.exist? path
    end
    
    def make_path ()
      FileUtils.mkpath(File.dirname(path))
      FileUtils.touch(path)
    end
    
    def truncate (size)
      make_path
      File.truncate(path, size)
    end
    
    def clone_command (source)
      [
        ["mkdir", "-p", File.dirname(path)],
        ["cp", "--reflink=always", source.path, path],
      ].map(&:shelljoin).join(";")
    end
    
    def clone (source)
      make_path
      system("cp", "--reflink=always", source.path, path)
    end
    
    def remove ()
      FileUtils.rm_f path
    end
    
    def stat ()
      File.stat(path)
    end
    
    def size ()
      stat.size
    end
    
  end
  
end
