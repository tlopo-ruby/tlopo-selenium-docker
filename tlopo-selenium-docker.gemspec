# frozen_string_literal: true

require_relative "lib/tlopo/selenium_docker/version"

Gem::Specification.new do |spec|
  spec.name = "tlopo-selenium-docker"
  spec.version = Tlopo::SeleniumDocker::VERSION
  spec.authors = ["tlopo"]
  spec.email = ["tlopo@github.com"]

  spec.summary = "Manges Selenium Docker container lifecycle and provides a handle to Selenium driver"
  spec.description = "Manges Selenium Docker container lifecycle and provides a handle to Selenium driver"
  spec.homepage = "https://github.com/tlopo-ruby/tlopo-selenium-docker"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage

  spec.files = [
    "lib/tlopo/selenium_docker.rb",
    "lib/tlopo/selenium_docker/version.rb",
    "lib/tlopo-selenium-docker.rb",
    "README.md",
    "LICENSE.txt"
  ]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "docker-api", "~> 2.3.0"
  spec.add_dependency "selenium-webdriver", "~> 4.25.0"
  spec.add_dependency "timeout", "~> 0.4.1"
  spec.add_dependency "tlopo-futex", "~> 0.1.0"
  spec.add_dependency "zlib", "~> 3.1.0"

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
