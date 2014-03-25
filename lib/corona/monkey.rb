
class File
  
  def write (path, data)
    File.open(path, "w") do |io|
      io.puts data
    end
  end
  
end

module Kernel
  
  def synchronous_fork ()
    IO.pipe do |pin, pout|
      fork do
        begin
          Process.daemon(true, true)
          yield
        rescue Exception => e
          pout.puts(Marshal.dump(e))
        end
      end
      pout.close
      if (e = pin.read) != ""
        raise Marshal.load(e)
      end
    end
  end
  
end

