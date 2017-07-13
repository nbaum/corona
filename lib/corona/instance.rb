# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

require "open3"
require "corona/task"
require "corona/qmp"
require "corona/qga"
require "yaml"

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

    def start (args = {})
      configure_guest_config
      configure_dhcp
      super(command(args))
      File.write(path("command"), command(args).shelljoin)
      qmp("set_password", protocol: "vnc", password: config[:password]) unless config[:password].empty?
      qmp("cont")
    end

    def status
      if !running?
        :stopped
      else
        :running
      end
    end

    def config
      @config ||= YAML.load(File.read(path("config.yml")))
    rescue
      @config = {}
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
              v.gsub(",", ",,")
            end.join(",")
          end
        end
      end
      s
    end

    def state_path (*tag)
      File.join("var", "state", *tag)
    end

    def migrate_to (host_or_file, port = nil)
      fail "I can't migrate a VM that isn't running" unless running?
      uri = if port
              "tcp:#{host_or_file}:#{port}"
            else
              FileUtils.mkpath state_path
              path = state_path(host_or_file)
              "exec:cat>#{path.shellescape}"
            end
      qmp(:migrate, uri: uri)
      qmp(:migrate_set_speed, value: 0)
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

    def migrate_cancel
      qmp("migrate_cancel")
    end

    def migrate_status
      qmp("query-migrate")
    end

    def migrate_wait
      qm = qmp("query-migrate")
      case status = qm["status"]
      when "setup", "active"
        qm
      when "completed"
        false
      else
        fail "Migration #{status}"
      end
    end

    def pause
      qmp("stop")
    end

    def unpause
      qmp("cont")
    end

    def qmp (command, arguments = {})
      qmp_socket.execute(command, arguments || {})
    rescue Errno::EPIPE
      @qmp_socket = nil
      sleep 0.1
      retry
    end

    def qga (command, arguments = {})
      tries = 2
      begin
        Timeout.timeout 0.25 do
          qga_socket.execute(command, arguments || {})
        end
      rescue Timeout::Error, Errno::EPIPE, Errno::ECONNREFUSED, Errno::ENOENT => e
        @qga_socket.close if @qga_socket
        @qga_socket = nil
        fail "Guest agent doesn't seem to be running" if (tries -= 1) == 0
        sleep 0.1
        retry
      end
    end

    protected

    def dhcp_host_line
      "#{config[:mac]},#{config[:ip]},#{config[:hostname]}" if config[:ip]
    end

    private

    def system (*command, &_block)
      out, status = Open3.capture2e(*command)
      status.success? ? out : fail(out)
    end

    def configure_guest_config
      return unless config[:guest_data]
      FileUtils.rm_rf(path("floppy"))
      FileUtils.mkpath(path("floppy"))
      config[:guest_data].each do |key, value|
        File.write(path("floppy", key), "#{value}\n")
      end
    end

    def configure_dhcp
      return unless gd = config[:guest_data]
      config[:ports].each do |port|
        next unless port && port[:mac]
        File.write Corona.path("dhcp/#{port[:mac]}"),
                   { address: [gd["net0.address"], gd["net0.prefix"]].join("/"),
                     gateway: gd["net0.gateway"],
                     dns: "8.8.8.8",
                     hostname: gd[:hostname],
                     vendor: @id.to_s }.to_json
      end
    end

    def qmp_socket
      fail NotRunning, log unless running?
      @qmp_socket ||= QMP.new(UNIXSocket.new(path("qmp")))
    rescue Errno::ECONNREFUSED, Errno::ENOENT
      sleep 0.1
      retry
    end

    def qga_socket
      fail NotRunning, log unless running?
      @qga_socket ||= begin
        @qga_socket = UNIXSocket.new(path("qga"))
        QGA.new(@qga_socket)
      end
    end

    def default_arguments
      args = {
        "qmp" => [["unix:#{path('qmp')}", "server", "nowait", "nodelay"]],
        "nodefaults" => true,
        "enable-kvm" => true,
        "S" => true,
        "vga" => "std",
        "drive" => [file: "fat:floppy:12:#{path('floppy')}", if: "floppy", index: 0, format: "raw"],
        "usb" => true,
        "chardev" => [
          ["socket", "server", "nowait", "nodelay", id: 'qga0', path: path('qga')],
          ["file", id: "log0", path: path("serial.log")]
        ],
        "device" => [],
      }
      extra = {
        "pc" => {
        },
        "pvpc" => {
          "device" => [["pvpanic"]],
          "watchdog" => [["i6300esb"]],
          "serial" => [["chardev:log0"]],
          "fsdev" => [['local', path: path('floppy'), security_model: 'none', id: 'configfs']]
        },
        "windows" => {
        },
        "mac" => {
        }
      }[config[:type].to_s]
      merge_options args, extra
    end

    def drive_if
      {
        "pc" => "ide",
        "pvpc" => "virtio",
        "windows" => "ide",
        "mac" => "ide"
      }[config[:type].to_s]
    end

    def net_driver
      {
        "pc" => "e1000",
        "pvpc" => "virtio-net",
        "windows" => "rtl8139",
        "mac" => "e1000"
      }[config[:type].to_s]
    end

    # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
    def arguments (extra = {})
      a = default_arguments.merge(config["arguments"] || {})
      a["m"] = [config[:memory]]
      a["smp"] = [cpus: config[:cores], maxcpus: 40]
      a["boot"] = [order: config[:boot_order] || "cdn", menu: "on", splash: "splash.bmp", "splash-time" => "1500"]
      if config[:password].empty?
        a["vnc"] = [[":#{config[:display]}"]]
      else
        a["vnc"] = [[":#{config[:display]}", "password"]]
      end
      a["net"] = []
      config[:ports].each.with_index do |port, i|
        next unless port
        a["net"] << ["bridge", vlan: i, name: port[:if], br: port[:net]]
        a["device"] << [[net_driver, addr: port[:addr], vlan: i, mac: port[:mac]]]
      end
      a["name"] = [config[:name], process: config[:name], "debug-threads" => "on"]
      a["cpu"] = "qemu64,+vmx"
      if cd = config[:cd]
        a["drive"] << [id: "drivex", if: "ide", format: "raw", media: "cdrom", snapshot: "on", cache: "writeback",
                       file: Volume.new(cd[:path]).qemu_url]
      end
      if hd = config[:hd] || config[:hda]
        a["drive"] << [id: "drive0", if: drive_if, serial: hd[:serial], format: "raw", snapshot: hd[:ephemeral] ? "on" : "off", cache: "writeback",
                       file: Volume.new(hd[:path]).qemu_url]
      end
      if hd = config[:hdb]
        a["drive"] << [id: "drive1", if: drive_if, serial: hd[:serial], format: "raw", snapshot: hd[:ephemeral] ? "on" : "off", cache: "writeback",
                       file: Volume.new(hd[:path]).qemu_url]
      end
      if hd = config[:hdc]
        a["drive"] << [id: "drive2", if: drive_if, serial: hd[:serial], format: "raw", snapshot: hd[:ephemeral] ? "on" : "off", cache: "writeback",
                       file: Volume.new(hd[:path]).qemu_url]
      end
      if hd = config[:hdd]
        a["drive"] << [id: "drive3", if: drive_if, serial: hd[:serial], format: "raw", snapshot: hd[:ephemeral] ? "on" : "off", cache: "writeback",
                       file: Volume.new(hd[:path]).qemu_url]
      end
      a["device"] << ["usb-tablet"]
      merge_options a, extra
    end
    # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

    def merge_options (a, b)
      c = {}
      a.each do |k, v|
        c[k.to_s] = [a[k]].flatten(1)
      end
      b.each do |k, v|
        c[k.to_s] ||= []
        c[k.to_s] += [v].flatten(1)
      end
      c
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
