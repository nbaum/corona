require 'open3'
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

    def start_ports
      config[:ports].each.with_index do |port|
      end
    end

    def start (args = {})
      configure_guest_config
      start_ports
      super(command(args))
      File.write(path("command"), command(args).shelljoin)
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

    def command (args = {})
      s = ["qemu-system-x86_64"]
      arguments(args).each do |option, values|
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

    def state_path (*tag)
      File.join("var", "state", *tag)
    end

    def migrate_to (host_or_file, port = nil)
      raise "I can't migrate a VM that isn't running" unless running?
      uri = if port
        "tcp:#{host_or_file}:#{port}"
      else
        FileUtils.mkpath state_path
        path = state_path(host_or_file)
        "exec:cat>#{path.shellescape}"
      end
      qmp(:migrate, uri: uri)
      migrate_wait()
    end

    def migrate_from (host_or_file, port = nil)
      uri = if port
        "tcp:#{host_or_file}:#{port}"
      else
        FileUtils.mkpath state_path
        path = state_path(host_or_file)
        "exec:cat<#{path.shellescape}"
      end
      start(incoming: uri)
    end

    def migrate_wait ()
      while ["setup", "active"].member?(p qmp("query-migrate")["status"])
        sleep 0.1
      end
      raise "Migration failed: #{log}" if qmp("query-migrate")["status"] == "failed"
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

    private

    def system (*command, &block)
      out, status = Open3.capture2e(*command)
      status.success? ? out : raise(out)
    end

    def configure_guest_config
      return unless config[:guest_data]
      FileUtils.rm_rf(path("floppy"))
      FileUtils.mkpath(path("floppy"))
      config[:guest_data].each do |key, value|
        File.write(path("floppy", key), "#{value}\n")
      end
    end

    def qmp_socket
      raise NotRunning, log unless running?
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
        "fda" => "fat:floppy:12:#{path("floppy")}"
      }
    end

    def arguments (extra = {})
      a = default_arguments.merge(config["arguments"] || {})
      gd = config[:guest_data]
      a["m"] = config[:memory]
      a["smp"] = config[:cores]
      a["boot"] = [order: config[:boot_order] || "cdn", menu: "on", splash: "splash.bmp", "splash-time" => "1500"]
      if config[:password].empty?
        a["vnc"] = [[":#{config[:display]}"]]
      else
        a["vnc"] = [[":#{config[:display]}", "password"]]
      end
      a["net"] = []
      config[:ports].each.with_index do |port, i|
        a["net"] << ["bridge", vlan: i, name: port[:if], br: port[:net]]
        a["device"] << [["e1000-82545em", vlan: i, mac: port[:mac]]]
      end
      a["name"] = [config[:name], process: config[:name], "debug-threads" => "on"]
      if config[:type] == "mac"
        a["cpu"] = "host,+vmx"
        a["machine"] = "q35"
        a["device"] << ["usb-kbd"]
        a["device"] << ["usb-mouse"]
        a["device"] << ["isa-applesmc", osk: "ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"]
        a["device"] << ["ide-hd", bus: "ide.2", drive: "drive0"]
        a["drive"] << [id: "drive0", if: "none", file: Volume.new(config[:hd]).path]
        if config[:cd]
          a["device"] << ["ide-cd", bus: "ide.0", drive: "drive1"]
          a["drive"] << [id: "drive1", format: "raw", if: "none", snapshot: "on", file: Volume.new(config[:cd]).path]
        end
        a["kernel"] = "./chameleon.bin"
        a["append"] = "idlehalt=0"
        a["smbios"] = [{type: 2}]
      else
        a["cpu"] = "host,+vmx"
        #a["device"] << ["piix3-ide"]
        #a["device"] << ["ide-hd", bus: "ide.2", drive: "drive0"]
        #a["drive"] << [id: "drive0", if: "none", file: Volume.new(config[:hd]).path, discard: "unmap", format: "raw", "detect-zeroes" => "unmap"]
        #if config[:cd]
        #  a["device"] << ["ide-cd", bus: "ide.1", drive: "drive1"]
        #  a["drive"] << [id: "drive1", format: "raw", if: "none", readonly: "on", file: Volume.new(config[:cd]).path]
        #end
        a["hda"] = Volume.new(config[:hd]).path if config[:hd]
        a["cdrom"] = Volume.new(config[:cd]).path if config[:cd]
        a["device"] << ["usb-tablet"]
      end
      a.merge(extra)
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
