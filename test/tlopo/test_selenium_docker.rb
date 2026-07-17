# frozen_string_literal: true

require "test_helper"

module Tlopo
  module Selenium
    class TestDocker < Minitest::Test
      def test_that_it_has_a_version_number
        refute_nil ::Tlopo::Selenium::Docker::VERSION
      end

      def test_it_does_something_useful
        assert false
      end
    end
  end
end
