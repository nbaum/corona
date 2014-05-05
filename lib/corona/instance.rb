
require 'corona/task'
require 'corona/qmp_socket'

require 'yaml'

module Corona
  
  class Instance < Task
    include Cached
    
    attr_reader :config
    
    def self.[] (id)
      new(id)
    end
    
    def initialize (id, config = nil)
      super(id)
      self.config = config if config
    end
    
    def start
      configure_floppy
      volume = root_volume
      volume.truncate(config[:storage] * 1000000000) if config[:storage]
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
    
    def config= (data)
      mkpath
      File.write(path("config.yml"), data.to_yaml)
      @config = data
    end
    
    def config ()
      @config ||= (YAML.load(File.read(path("config.yml"))) rescue {})
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
    
    def clone (from)
      mkpath
      if from.running?
        commands = [
          "cat>#{path('state').shellescape}",
          root_volume.clone_command(from.root_volume),
          "false"
        ]
        from.qmp(:migrate, uri: "exec:" + commands.join(";"))
        while (p from.qmp("query-migrate")["status"]) == "active"
          sleep 0.01
        end
      else
        root_volume.clone(from.root_volume)
      end
    end
    
    def qmp (command, arguments = {})
      qmp_socket.execute(command, arguments)
    rescue Errno::EPIPE
      @socket = nil
      sleep 0.1
      retry
    end
    
    protected
    
    def dhcp_host_line
      if config[:ip]
        "#{config[:mac]},#{config[:ip]},#{config[:hostname]}"
      end
    end
    
    def root_volume
      Volume.new("vm#{@id}/root")
    end
    
    private
    
    def configure_floppy
      FileUtils.rm_rf(path("floppy"))
      FileUtils.mkpath(path("floppy"))
      config[:guest_data].each do |key, value|
        File.write(path("floppy", key), value)
      end
    end
    
    def qmp_socket ()
      @socket ||= QmpSocket.new(path("qmp"))
    rescue Errno::ECONNREFUSED, Errno::ENOENT
      sleep 0.1
      retry
    end
    
    def default_arguments
      {
        "qmp" => [["unix:#{path("qmp")}", "server", "nowait", "nodelay"]],
        "nodefaults" => true,
        "enable-kvm" => true,
        "S" => true,
        "drive" => [],
        "vga" => "std",
        "boot" => [menu: "on"],
        "usb" => true,
        "usbdevice" => "tablet",
        "boot" => "order=cdn",
        "fda" => "fat:floppy:#{path("floppy")}",
      }
    end
    
    def arguments
      a = default_arguments.merge(config["arguments"] || {})
      a["m"] = config[:memory]
      a["smp"] = config[:cores]
      a["hda"] = root_volume.path
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

