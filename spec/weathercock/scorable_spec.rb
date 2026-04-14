# frozen_string_literal: true

require "weathercock/scorable"

RSpec.describe Weathercock::Scorable do
  around do |example|
    original = Weathercock.instance_variable_get(:@config)
    example.run
    Weathercock.instance_variable_set(:@config, original)
  end

  before do
    @pipeline = instance_double("RedisClient::Pipeline")
    allow(@pipeline).to receive(:call)
    @redis = instance_double("RedisClient")
    allow(@redis).to receive(:pipelined).and_yield(@pipeline)
    Weathercock.configure { |c| c.redis = @redis }
    Timecop.freeze(Time.new(2026, 4, 15, 9, 0, 0))
    stub_const("Article", Class.new do
      include Weathercock::Scorable
      def id = 42
    end)
    @article = Article.new
  end

  describe "#hit" do
    it "uses underscored qualified class name in the key" do
      stub_const("Blog::Article", Class.new do
        include Weathercock::Scorable
        def id = 1
      end)
      Blog::Article.new.hit(:views)
      expect(@pipeline).to have_received(:call).with("ZINCRBY","weathercock:blog_article:views:2026-04-15-09", 1, "1")
    end

    it "writes to hourly key" do
      @article.hit(:views)
      expect(@pipeline).to have_received(:call).with("ZINCRBY","weathercock:article:views:2026-04-15-09", 1, "42")
    end

    it "writes to daily key" do
      @article.hit(:views)
      expect(@pipeline).to have_received(:call).with("ZINCRBY","weathercock:article:views:2026-04-15", 1, "42")
    end

    it "writes to monthly key" do
      @article.hit(:views)
      expect(@pipeline).to have_received(:call).with("ZINCRBY","weathercock:article:views:2026-04", 1, "42")
    end

    it "accepts increment option" do
      @article.hit(:views, increment: 5)
      expect(@pipeline).to have_received(:call).with("ZINCRBY","weathercock:article:views:2026-04-15", 5, "42")
    end
  end

  describe ".top" do
    before do
      allow(@redis).to receive(:call).with("ZUNIONSTORE", any_args).and_return(7)
      allow(@redis).to receive(:call).with("ZREVRANGE", any_args).and_return(["42", "7", "133"])
    end

    it "unions last N daily keys" do
      Article.top(:views, days: 7)
      expect(@redis).to have_received(:call).with(
        "ZUNIONSTORE", anything, 7,
        "weathercock:article:views:2026-04-15",
        "weathercock:article:views:2026-04-14",
        "weathercock:article:views:2026-04-13",
        "weathercock:article:views:2026-04-12",
        "weathercock:article:views:2026-04-11",
        "weathercock:article:views:2026-04-10",
        "weathercock:article:views:2026-04-09"
      )
    end

    it "unions last N hourly keys" do
      Article.top(:views, hours: 3)
      expect(@redis).to have_received(:call).with(
        "ZUNIONSTORE", anything, 3,
        "weathercock:article:views:2026-04-15-09",
        "weathercock:article:views:2026-04-15-08",
        "weathercock:article:views:2026-04-15-07"
      )
    end

    it "unions last N monthly keys" do
      Article.top(:views, months: 3)
      expect(@redis).to have_received(:call).with(
        "ZUNIONSTORE", anything, 3,
        "weathercock:article:views:2026-04",
        "weathercock:article:views:2026-03",
        "weathercock:article:views:2026-02"
      )
    end

    it "returns ids in descending order" do
      result = Article.top(:views, days: 7)
      expect(result).to eq(["42", "7", "133"])
    end
  end
end
