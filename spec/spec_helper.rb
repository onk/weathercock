# frozen_string_literal: true

require "weathercock"
require "timecop"
require "redis-client"

RSpec.configure do |config|
  if ENV.key?("TRACE")
    require "rbs/trace"
    trace = RBS::Trace.new
    config.before(:suite) { trace.enable }
    config.after(:suite) do
      trace.disable
      trace.save_files(out_dir: "sig/trace/")
    end
  end

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  redis = nil

  config.before(:suite) do
    redis = RedisClient.new(host: "localhost", port: 6379)
    Weathercock.configure { |c| c.redis = redis }
  end

  config.after do
    Timecop.return
    redis.call("FLUSHDB")
  end
end
