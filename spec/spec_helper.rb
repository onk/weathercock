# frozen_string_literal: true

require "weathercock"
require "timecop"
require "redis-client"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    Weathercock.configure { |c| c.redis = RedisClient.new(host: "localhost", port: 6379) }
  end

  config.after do
    Timecop.return
    Weathercock.config.redis.call("FLUSHDB")
  end
end
