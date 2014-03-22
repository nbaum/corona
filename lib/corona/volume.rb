
require 'corona/errors'
require 'fileutils'

module Corona

  class Volume
    
    attr_accessor :path
    
    def self.root
      File.expand_path("var/storage")
    end
    
    def self.list (path = "")
      Dir[File.join(root, path, "**/*")].select do |path|
        File.file?(path)
      end.map do |path|
        new(path)
      end
    end
    
    def self.create (path)
      v = new(path)
      raise Error, "#{path} already exists" if v.exist?
      v
    end
    
    def self.open (path)
      v = new(path)
      raise Error, "#{path} doesn't exist" unless v.exist?
      v
    end
    
    def initialize (path)
      @path = File.expand_path(path, Volume.root)
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
    
    def clone (source)
      make_path
      system("cp", "--reflink=always", source.path, path)
    end
    
    def remove ()
      FileUtils.rm_f path
    end
    
  end
  
end
