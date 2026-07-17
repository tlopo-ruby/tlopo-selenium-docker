# frozen_string_literal: true

require "test_helper"
require "socket"
require "tmpdir"
require "json"
require "digest"

module Tlopo
  class SeleniumDockerIntegrationTest < Minitest::Test
    CONTAINER_HOST_ALIAS = "host.docker.internal"
    SELENIUM_IMAGE = "selenium/standalone-chromium:4.21.0"
    VIDEO_IMAGE = "selenium/video:ffmpeg-7.1-20241101"
    VIDEO_OUTPUT_PATH = "/tmp/tlopo-selenium-docker-session.mp4"
    PAGE_DWELL_SECONDS = 1
    PAGE_TITLE = "Dummy Server"
    MARKER_TEXT = "hello from dummy"
    PAGE_BODY = <<~HTML.freeze
      <!DOCTYPE html>
      <html>
        <head><title>#{PAGE_TITLE}</title></head>
        <body><h1 id="marker">#{MARKER_TEXT}</h1></body>
      </html>
    HTML

    class DummyServer
      attr_reader :port

      def initialize
        @listener = TCPServer.new("0.0.0.0", 0)
        @port = @listener.addr[1]
        @acceptor = Thread.new { accept_loop }
      end

      def accept_loop
        loop do
          connection = @listener.accept
          Thread.new(connection) { |socket| respond(socket) }
        end
      rescue IOError, Errno::EBADF
        nil
      end

      def respond(socket)
        socket.gets while (header = socket.gets) && header != "\r\n"
        socket.write(http_response)
      rescue IOError, Errno::EPIPE
        nil
      ensure
        socket.close
      end

      def http_response
        [
          "HTTP/1.1 200 OK",
          "Content-Type: text/html; charset=utf-8",
          "Content-Length: #{PAGE_BODY.bytesize}",
          "Connection: close",
          "",
          PAGE_BODY
        ].join("\r\n")
      end

      def stop
        @listener.close
        @acceptor.join(1)
      end
    end

    Session = Struct.new(:title, :marker, :video_path)

    def setup
      Docker.url = active_context_endpoint if ENV["DOCKER_HOST"].to_s.empty?
      Docker.version
    rescue StandardError => e
      skip "Docker daemon unavailable: #{e.message}"
    end

    def active_context_endpoint
      name = ENV["DOCKER_CONTEXT"] || current_context_name
      return Docker.url if name.nil? || name == "default"

      digest = Digest::SHA256.hexdigest(name)
      meta_path = File.join(docker_config_dir, "contexts", "meta", digest, "meta.json")
      return Docker.url unless File.exist?(meta_path)

      JSON.parse(File.read(meta_path)).dig("Endpoints", "docker", "Host") || Docker.url
    end

    def current_context_name
      config_path = File.join(docker_config_dir, "config.json")
      return nil unless File.exist?(config_path)

      JSON.parse(File.read(config_path))["currentContext"]
    end

    def docker_config_dir
      ENV["DOCKER_CONFIG"] || File.join(Dir.home, ".docker")
    end

    def build_selenium(video_path)
      SeleniumDocker.new(
        selenium_image: SELENIUM_IMAGE,
        video_image: VIDEO_IMAGE,
        video_path: video_path
      )
    end

    def run_session(server)
      FileUtils.rm_f(VIDEO_OUTPUT_PATH)
      session = Session.new(nil, nil, VIDEO_OUTPUT_PATH)
      build_selenium(session.video_path).run do |driver|
        driver.navigate.to("http://#{CONTAINER_HOST_ALIAS}:#{server.port}")
        sleep(PAGE_DWELL_SECONDS)
        session.title = driver.title
        session.marker = driver.find_element(id: "marker").text
      end
      session
    end

    def test_records_video_of_session_against_dummy_server
      server = DummyServer.new
      session = run_session(server)

      assert_equal PAGE_TITLE, session.title
      assert_equal MARKER_TEXT, session.marker
      assert_recorded_video(session.video_path)
    ensure
      server&.stop
    end

    def assert_recorded_video(path)
      assert File.exist?(path), "expected recorded video at #{path}"
      assert File.size(path).positive?, "expected recorded video to be non-empty"
      puts "\nRecorded video available at #{path}"
    end
  end
end
