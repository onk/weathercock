# frozen_string_literal: true

RSpec.describe Weathercock do
  it "has a version number" do
    expect(Weathercock::VERSION).not_to be nil
  end

  describe ".configure" do
    around do |example|
      original = Weathercock.instance_variable_get(:@config)
      example.run
      Weathercock.instance_variable_set(:@config, original)
    end

    it "yields a config object" do
      expect { |b| Weathercock.configure(&b) }.to yield_with_args(Weathercock::Config)
    end

    it "namespace defaults to 'weathercock'" do
      expect(Weathercock.config.namespace).to eq("weathercock")
    end

    it "sets namespace" do
      Weathercock.configure { |c| c.namespace = "myapp" }
      expect(Weathercock.config.namespace).to eq("myapp")
    end

    it "sets redis" do
      redis = RedisClient.new
      Weathercock.configure { |c| c.redis = redis }
      expect(Weathercock.config.redis).to eq(redis)
    end
  end
end
