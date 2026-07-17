# frozen_string_literal: true

require "test_helper"

module Tlopo
  class TestSeleniumDocker < Minitest::Test
    def setup
      @created_workspaces = []
      @held_locks = []
    end

    def teardown
      @held_locks.each(&:release)
      @created_workspaces.each { |path| FileUtils.rm_rf path }
    end

    def hold_lock(port)
      lock = Tlopo::Futex.new("/tmp/.selenium-docker-#{port}")
      lock.lock
      @held_locks << lock
    end

    def build(opts = {})
      instance = SeleniumDocker.new(opts)
      @created_workspaces << instance.instance_variable_get(:@ws)
      instance
    end

    def test_version_is_defined
      refute_nil SeleniumDocker::VERSION
      assert_match(/\A\d+\.\d+\.\d+\z/, SeleniumDocker::VERSION)
    end

    def test_default_images_are_used
      instance = build
      assert_equal "selenium/standalone-chrome:4.8.3", instance.instance_variable_get(:@selenium_image)
      assert_equal "selenium/video:ffmpeg-4.3.1-20220726", instance.instance_variable_get(:@video_image)
    end

    def test_options_override_defaults
      instance = build(selenium_image: "selenium/standalone-firefox:latest", video_path: "/tmp/out.mp4")
      assert_equal "selenium/standalone-firefox:latest", instance.instance_variable_get(:@selenium_image)
      assert_equal "/tmp/out.mp4", instance.instance_variable_get(:@video_path)
    end

    def test_generated_id_is_base36
      instance = build
      assert_match(/\A[0-9a-z]+\z/, instance.gen_short_id)
    end

    def test_workspace_directory_is_created
      instance = build
      assert File.directory?(instance.instance_variable_get(:@ws))
    end

    def test_find_free_port_returns_port_within_range
      instance = build
      port = instance.find_free_port(8100, 8150)
      assert_includes 8100..8150, port
    end

    def test_find_free_port_raises_when_every_port_is_locked
      instance = build
      reserved_port = 8150
      hold_lock(reserved_port)
      assert_raises(SeleniumDocker::NoFreePortError) do
        instance.find_free_port(reserved_port, reserved_port)
      end
    end
  end
end
