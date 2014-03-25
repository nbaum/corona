
require 'corona/task'
require 'corona/qmp_socket'

require 'yaml'

module Corona
  
  class Instance < Task
    
    attr_reader :config
    
    def self.[] (id)
      new(id)
    end
    
    def initialize (id, config = nil)
      super(id)
      self.config = config if config
    end
    
    def dhcp_host_line
      if config[:ip]
        "#{config[:mac]},#{config[:ip]},#{config[:hostname]}"
      end
    end
    
    def configure_dhcp
      config = Instance.all.map do |i|
        i.dhcp_host_line
      end.compact.join("\n")
      File.write("var/dhcp-hosts", config + "\n")
    end
    
    def start
      configure_dhcp
      super
      qmp("set_password", protocol: "vnc", password: config[:password])
      qmp("cont")
    end
    
    def status
      if !running?
        :stopped
      else
        :running
      end
    end
    
    def qmp (command, arguments = {})
      qmp_socket.execute(command, arguments)
    end
    
    def config= (data)
      mkpath
      File.write(path("config.yml"), data.to_yaml)
      @config = data
    end
    
    def config ()
      @config ||= YAML.load(File.read(path("config.yml")))
    end
    
    def command ()
      s = ["qemu-system-x86_64"]
      arguments.each do |option, values|
        Array(values).each do |value|
          case value
          when nil, false
          when true
            s << "-#{option}"
          else
            s << "-#{option}"
            s << format_option(value).map do |v|
              v.gsub(',', ',,')
            end.join(',')
          end
        end
      end
      puts "EXECUTE: #{s.shelljoin}"
      s
    end
    
    private
    
    def qmp_socket ()
      @socket ||= QmpSocket.new(self)
    rescue Errno::ECONNREFUSED, Errno::ENOENT
      retry
    end
    
    def default_arguments
      {
        "nodefaults" => true,
        "qmp" => [["unix:#{path("qmp")}", "server", "nowait", "nodelay"]],
        "S" => true,
        "enable-kvm" => true,
        "usb" => true,
        "vga" => "std",
        "drive" => []
      }
    end
    
    def arguments
      a = default_arguments.merge(config["arguments"] || {})
      a["m"] = config[:memory]
      a["smp"] = config[:cores]
      volume = Volume.new("vm#{@id}/root")
      volume.truncate(config[:storage] * 1000000000) if config[:storage]
      a["hda"] = volume.path
      a["cdrom"] = Volume.new(config[:iso]).path if config[:iso]
      a["vnc"] = [[":#{config[:display]}", "password", "websocket"]]
      a["net"] = [["bridge", br: "br0"], ["nic", macaddr: config[:mac]]]
      a
    end
    
    def format_option (value)
      case value
      when Array
        value.flat_map do |v|
          format_option(v)
        end
      when Hash
        value.flat_map do |k, v|
          "#{k}=#{v}"
        end
      else
        [value.to_s]
      end
    end
    
  end
  
end

