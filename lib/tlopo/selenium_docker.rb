# frozen_string_literal: true

require_relative "selenium_docker/version"
require "zlib"
require "fileutils"
require "timeout"
require "socket"
require "docker"
require "tlopo/futex"
require "logger"
require "selenium-webdriver"

module Tlopo
  class SeleniumDocker
    LOGGER ||= Logger.new $stderr

    def initialize(opts = {})
      @selenium_image = opts[:selenium_image] || "selenium/standalone-chrome:4.8.3"
      @video_image = opts[:video_image] || "selenium/video:ffmpeg-4.3.1-20220726"
      @chrome_data_dir = opts[:chrome_data_dir] || nil
      @video_path = opts[:video_path] || nil
      @name = "selenium-#{gen_short_id}"
      @ws = "/tmp/#{@name}"
      FileUtils.mkdir_p @ws
      FileUtils.mkdir_p @chrome_data_dir if @chrome_data_dir
    end

    def run
      start
      yield driver
    ensure
      driver.quit
      stop
    end

    def gen_short_id
      Zlib.crc32(Time.now.strftime("%s.%N")).to_s(36)
    end

    def get_port_lock(port)
      filename = "/tmp/.selenium-docker-#{port}"
      f = Tlopo::Futex.new(filename)
      f.lock
      f
    end

    def start
      pull_images
      lock_chrome_data_dir if @chrome_data_dir
      @port = find_free_port 8100, 8150
      @port_lock = get_port_lock @port
      @vnc_port = find_free_port 5900, 5950
      @vnc_port_lock = get_port_lock @vnc_port
      create_network
      start_selenium
      start_video if @video_path
    end

    def stop
      stop_video if @video_path
      stop_selenium
      remove_network
      @port_lock.release
      @vnc_port_lock.release
      @chrome_data_dir_lock&.release
      copy_video
      FileUtils.rm_rf @ws
    end

    def copy_video
      return unless @video_path

      path = @video_path =~ /\.mp4$/ ? @video_path : "#{@video_path}.mp4"
      FileUtils.cp "#{@ws}/video/video.mp4", path
      LOGGER.debug "Recorded video saved to '#{path}''"
    end

    def find_free_port(from, to)
      (from..to).each do |port|
        next if Tlopo::Futex.new("/tmp/.selenium-docker-#{port}").locked?

        Timeout.timeout(1) { TCPSocket.new("127.0.0.1", port).close }
      rescue Errno::ECONNREFUSED
        return port
      end
    end

    def pull_images
      [@selenium_image, @video_image].each do |image|
        unless Docker::Image.exist? image
          LOGGER.debug "Pulling image #{image}"
          Docker::Image.create("fromImage" => image)
        end
      end
    end

    def create_network
      network_name = @name.to_s
      return if Docker::Network.all.map(&:info).any? { |n| n["Name"] == network_name }

      LOGGER.debug "Creating network #{network_name}"
      Docker::Network.create network_name
    end

    def remove_network
      network_name = @name.to_s
      return unless Docker::Network.all.map(&:info).any? { |n| n["Name"] == network_name }

      LOGGER.debug "Removing network #{network_name}"
      Docker::Network.get(network_name).remove
    end

    def get_container(container_name)
      Docker::Container.get(container_name)
    rescue Docker::Error::NotFoundError
      nil
    end

    def stop_container(container_name, timeout = 30)
      c = get_container(container_name)
      return if c.nil?

      LOGGER.debug "Stopping container '#{container_name}'"
      c.stop t: timeout
    end

    def lock_chrome_data_dir
      @chrome_data_dir_lock = Tlopo::Futex.new("#{@chrome_data_dir}/.chrome_data_dir.lock")
      @chrome_data_dir_lock.lock
    end

    def start_selenium
      ws = @chrome_data_dir || "/#{@ws}/chrome-data-dir"
      LOGGER.debug "Starting selenium, container name: #{@name}, vnc port: #{@vnc_port}"
      Docker::Container.create(
        Image: @selenium_image,
        name: @name.to_s,
        HostConfig: {
          NetworkMode: @name.to_s,
          AutoRemove: true,
          PortBindings: {
            "4444/tcp": [{ HostPort: @port.to_s }],
            "5900/tcp": [{ HostPort: @vnc_port.to_s }]
          },
          "Binds" => ["#{ws}:/tmp/chrome-data-dir"],
          "ShmSize" => 2 * 1024 * 1024 * 1024 # 2 GB in bytes
        },
        Env: ["VIDEO=true"]
      ).start
    end

    def stop_selenium
      stop_container @name.to_s
    end

    def start_video
      LOGGER.debug "Starting video, container name: #{@name}-video"
      Docker::Container.create(
        Image: @video_image,
        name: "#{@name}-video",
        HostConfig: {
          NetworkMode: @name.to_s,
          AutoRemove: true,
          "Binds" => ["#{@ws}/video:/videos"]
        },
        Env: ["DISPLAY_CONTAINER_NAME=#{@name}"]
      ).start
    end

    def stop_video
      stop_container "#{@name}-video"
    end

    def driver
      return @driver unless @driver.nil?

      Timeout.timeout(60) do
        loop do
          TCPSocket.new("localhost", @port).close
          url = "http://localhost:#{@port}/wd/hub"

          options = Selenium::WebDriver::Chrome::Options.new
          options.add_argument("--no-first-run")
          options.add_argument("--user-data-dir=/tmp/chrome-data-dir")

          @driver = Selenium::WebDriver.for :remote, url: url, capabilities: options
          LOGGER.debug "driver created for #{@name}"
          break
        rescue Errno::ECONNREFUSED
          sleep 0.5
        rescue EOFError
          sleep 0.5
        rescue Selenium::WebDriver::Error::UnknownError
          sleep 0.5
        end
      end
      @driver
    end
  end
end
