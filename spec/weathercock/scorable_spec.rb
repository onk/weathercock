# frozen_string_literal: true

require "weathercock/scorable"

RSpec.describe Weathercock::Scorable do
  around do |example|
    original = Weathercock.instance_variable_get(:@config)
    example.run
    Weathercock.instance_variable_set(:@config, original)
  end

  before do
    @redis = instance_double("RedisClient")
    allow(@redis).to receive(:call)
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
      expect(@redis).to have_received(:call).with("ZINCRBY", "weathercock:blog_article:views:2026-04-15-09", 1, "1")
    end

    it "writes to hourly key" do
      @article.hit(:views)
      expect(@redis).to have_received(:call).with("ZINCRBY", "weathercock:article:views:2026-04-15-09", 1, "42")
    end

    it "writes to daily key" do
      @article.hit(:views)
      expect(@redis).to have_received(:call).with("ZINCRBY", "weathercock:article:views:2026-04-15", 1, "42")
    end

    it "writes to monthly key" do
      @article.hit(:views)
      expect(@redis).to have_received(:call).with("ZINCRBY", "weathercock:article:views:2026-04", 1, "42")
    end

    it "accepts increment option" do
      @article.hit(:views, increment: 5)
      expect(@redis).to have_received(:call).with("ZINCRBY", "weathercock:article:views:2026-04-15", 5, "42")
    end
  end
end
