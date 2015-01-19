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
      configure_guest_config
      #volume = root_volume
      #volume.truncate(config[:storage] * 1000000000) if config[:storage]
      super
      File.write(path("command"), command.shelljoin)
      if !config[:password].empty?
        qmp("set_password", protocol: "vnc", password: config[:password])
      end
      qmp("cont")
    end
    
    def status
      if !running?
        :stopped
      else
        :running
      end
    end
    
    def config ()
      @config ||= (YAML.load(File.read(path("config.yml"))) rescue {})
    end
    
    def config= (data)
      mkpath
      File.write(path("config.yml"), data.to_yaml)
      @config = data
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
    
    def pause ()
      qmp("stop")
    end
    
    def unpause ()
      qmp("cont")
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
    
    #def root_volume
    #  Volume.new("vm#{@id}/root", "standard")
    #end
    
    private
    
    def configure_guest_config
      return unless config[:guest_data]
      FileUtils.rm_rf(path("floppy"))
      FileUtils.mkpath(path("floppy"))
      config[:guest_data].each do |key, value|
        File.write(path("floppy", key), "#{value}\n")
      end
    end
    
    def qmp_socket ()
      raise NotRunning unless running?
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
        "vga" => "std",
        "drive" => [],
        "device" => [],
        "usb" => true,
        "fda" => "fat:floppy:12:#{path("floppy")}",
      }
    end
    
    def arguments
      a = default_arguments.merge(config["arguments"] || {})
      a["m"] = config[:memory]
      a["smp"] = config[:cores]
      a["boot"] = [order: config[:boot_order] || "cdn", menu: "on", splash: "splash.bmp", "splash-time" => "1000"]
      if config[:password].empty?
        a["vnc"] = [[":#{config[:display]}"]]
      else
        a["vnc"] = [[":#{config[:display]}", "password"]]
      end
      a["netdev"] = [["bridge", id: "netdev0", br: ENV["BRIDGE"]]]
      a["device"] << [["e1000-82545em", netdev: "netdev0"]]
      a["name"] = [config[:name], process: config[:name], "debug-threads" => "on"]
      if config[:type] == "mac"
        a["cpu"] = "core2duo"
        a["machine"] = "q35"
        a["device"] << ["usb-kbd"]
        a["device"] << ["usb-mouse"]
        a["device"] << ["isa-applesmc", osk: "ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"]
        a["device"] << ["ide-drive", bus: "ide.2", drive: "drive0"]
        a["drive"] << [id: "drive0", if: "none", file: Volume.new(config[:hd]).path]
        if config[:cd]
          a["device"] << ["ide-drive", bus: "ide.0", drive: "drive1"]
          a["drive"] << [id: "drive1", if: "none", snapshot: "on", file: Volume.new(config[:cd]).path]
        end
        a["kernel"] = "./chameleon.bin"
        a["append"] = "idlehalt=0"
        a["smbios"] = [{type: 2}]
      else
        a["cdrom"] = Volume.new(config[:cd]).path if config[:cd]
        a["hda"] = Volume.new(config[:hd]).path if config[:hd]
        a["device"] << ["usb-tablet"]
      end
      a
    end
    
    def format_option (option)
      case option
      when Array
        option.flat_map do |v|
          format_option(v)
        end
      when Hash
        option.flat_map do |k, v|
          "#{k}=#{v}"
        end
      else
        [option.to_s]
      end
    end
    
  end
  
end
