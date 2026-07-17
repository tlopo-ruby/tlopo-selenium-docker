# Tlopo::SeleniumDocker

Manages the lifecycle of a Selenium Docker container and hands you a ready-to-use
`Selenium::WebDriver`. It pulls the images, allocates free host ports (guarded by file
locks so parallel runs don't collide), creates a dedicated Docker network, starts the
browser container, and optionally records a video of the session. Everything is torn
down when the block returns.

## Requirements

- A running Docker daemon reachable by [`docker-api`](https://github.com/swipely/docker-api)
- Ruby >= 2.6.0

## Installation

Add the gem to your Gemfile:

```ruby
gem "tlopo-selenium-docker"
```

Then run:

    $ bundle install

Or install it directly:

    $ gem install tlopo-selenium-docker

## Usage

```ruby
require "tlopo/selenium_docker"

Tlopo::SeleniumDocker.new.run do |driver|
  driver.navigate.to "https://example.com"
  puts driver.title
end
```

### Options

| Option             | Default                                    | Description                                          |
| ------------------ | ------------------------------------------ | ---------------------------------------------------- |
| `:selenium_image`  | `selenium/standalone-chrome:4.8.3`         | Image used for the browser container.                |
| `:video_image`     | `selenium/video:ffmpeg-4.3.1-20220726`     | Image used for the video recorder.                   |
| `:chrome_data_dir` | `nil`                                      | Host directory mounted as the Chrome user data dir.  |
| `:video_path`      | `nil`                                      | When set, records the session and copies it here.    |

### Recording a video

```ruby
Tlopo::SeleniumDocker.new(video_path: "session.mp4").run do |driver|
  driver.navigate.to "https://example.com"
end
```

The recording is written to `session.mp4` (the `.mp4` extension is appended if omitted)
once the block completes.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run
`rake test` to run the tests, or `bin/console` for an interactive prompt.

To install this gem onto your local machine, run `bundle exec rake install`.

### Tests

There are two suites:

- `rake test` — fast unit tests that do not require Docker. This is the default
  task (`rake`) and what CI runs.
- `rake integration` — an end-to-end test that starts a real Selenium container
  against an in-process dummy HTTP server and records the session to video. It
  requires a running Docker daemon and is skipped automatically when none is
  reachable.

The integration test resolves the daemon from the active Docker context (the
same one the `docker` CLI uses), so it works with Docker Desktop, Colima, and
others without extra configuration. Set `DOCKER_HOST` to override.

It uses the multi-arch `selenium/standalone-chromium` and `selenium/video`
images, so it runs natively on both amd64 and arm64 (Apple Silicon) hosts. The
recording is written to `/tmp/tlopo-selenium-docker-session.mp4`:

```
$ bundle exec rake integration
$ open /tmp/tlopo-selenium-docker-session.mp4
```

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/tlopo-ruby/tlopo-selenium-docker.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
