# frozen_string_literal: true

require "weathercock/scorer"

RSpec.describe Weathercock::Scorer do
  let(:redis) { Weathercock.config.redis }
  let(:scorer) { described_class.new }
  let(:klass) { Article }

  before do
    Timecop.freeze(Time.new(2026, 4, 15, 9, 0, 0))
    stub_const("Article", Class.new)
  end

  describe "#hit" do
    it "uses underscored qualified class name in the key" do
      stub_const("Blog::Article", Class.new)
      scorer.hit(Blog::Article, 1, :views)
      expect(redis.call("ZSCORE", "weathercock:blog_article:views:2026-04-15-09", "1")).to eq(1.0)
    end

    it "writes to total key" do
      scorer.hit(klass, 42, :views, increment: 3)
      expect(redis.call("ZSCORE", "weathercock:article:views:total", "42")).to eq(3.0)
    end

    it "writes to hourly key" do
      scorer.hit(klass, 42, :views)
      expect(redis.call("ZSCORE", "weathercock:article:views:2026-04-15-09", "42")).to eq(1.0)
    end

    it "writes to daily key" do
      scorer.hit(klass, 42, :views)
      expect(redis.call("ZSCORE", "weathercock:article:views:2026-04-15", "42")).to eq(1.0)
    end

    it "writes to monthly key" do
      scorer.hit(klass, 42, :views)
      expect(redis.call("ZSCORE", "weathercock:article:views:2026-04", "42")).to eq(1.0)
    end

    it "accepts increment option" do
      scorer.hit(klass, 42, :views, increment: 5)
      expect(redis.call("ZSCORE", "weathercock:article:views:2026-04-15", "42")).to eq(5.0)
    end

    it "sets TTL on hourly key" do
      scorer.hit(klass, 42, :views)
      expect(redis.call("TTL", "weathercock:article:views:2026-04-15-09")).to eq(3 * 24 * 3600)
    end

    it "sets TTL on daily key" do
      scorer.hit(klass, 42, :views)
      expect(redis.call("TTL", "weathercock:article:views:2026-04-15")).to eq(3 * 30 * 86400)
    end

    it "sets TTL on monthly key" do
      scorer.hit(klass, 42, :views)
      expect(redis.call("TTL", "weathercock:article:views:2026-04")).to eq(3 * 12 * 30 * 86400)
    end
  end

  describe "#hit_count" do
    it "returns score for the instance over a time window" do
      scorer.hit(klass, 42, :views)
      expect(scorer.hit_count(klass, 42, :views, days: 7)).to eq(1)
    end

    it "returns 0 when no hits recorded" do
      expect(scorer.hit_count(klass, 42, :views, days: 7)).to eq(0)
    end

    it "returns cumulative count when no window given" do
      scorer.hit(klass, 42, :views, increment: 5)
      expect(scorer.hit_count(klass, 42, :views)).to eq(5)
    end

    it "returns 0 for cumulative count when no hits recorded" do
      expect(scorer.hit_count(klass, 42, :views)).to eq(0)
    end
  end

  describe "#hit_counts" do
    before do
      scorer.hit(klass, 42, :views, increment: 2)
      scorer.hit(klass, 7, :views)
    end

    it "returns a hash of id => count for given ids" do
      result = scorer.hit_counts(klass, :views, ids: [42, 7], days: 7)
      expect(result).to eq("42" => 2, "7" => 1)
    end

    it "returns 0 for ids with no hits" do
      result = scorer.hit_counts(klass, :views, ids: [99], days: 7)
      expect(result).to eq("99" => 0)
    end

    it "returns cumulative counts when no window given" do
      result = scorer.hit_counts(klass, :views, ids: [42, 7])
      expect(result).to eq("42" => 2, "7" => 1)
    end
  end

  describe "#top" do
    before do
      scorer.hit(klass, 42, :views, increment: 2)
      scorer.hit(klass, 7, :views)
      scorer.hit(klass, 133, :views, increment: 3)
    end

    it "returns all-time ranking when no window given" do
      result = scorer.top(klass, :views, limit: nil)
      expect(result).to eq(["133", "42", "7"])
    end

    it "unions last N hourly keys" do
      result = scorer.top(klass, :views, hours: 24, limit: nil)
      expect(result).to eq(["133", "42", "7"])
    end

    it "unions last N daily keys" do
      result = scorer.top(klass, :views, days: 7, limit: nil)
      expect(result).to eq(["133", "42", "7"])
    end

    it "unions last N monthly keys" do
      result = scorer.top(klass, :views, months: 3, limit: nil)
      expect(result).to eq(["133", "42", "7"])
    end

    it "sets 15 min TTL on the temp key" do
      scorer.top(klass, :views, days: 7, limit: nil)
      ttl = redis.call("TTL", "weathercock:article:views:top:days:7")
      expect(ttl).to eq(900)
    end

    it "limits the number of results when limit is given" do
      expect(scorer.top(klass, :views, limit: 2)).to eq(["133", "42"])
    end

    it "limits the number of results with a window when limit is given" do
      expect(scorer.top(klass, :views, days: 7, limit: 2)).to eq(["133", "42"])
    end

    it "applies exponential decay weights when decay_factor is given" do
      Timecop.freeze(Time.new(2026, 4, 15, 7, 0, 0)) { scorer.hit(klass, 1, :views, increment: 10) }
      Timecop.freeze(Time.new(2026, 4, 15, 9, 0, 0)) { scorer.hit(klass, 2, :views, increment: 10) }
      scorer.top(klass, :views, hours: 3, decay_factor: 0.9, limit: nil)
      dest = "weathercock:article:views:top:hours:3"
      expect(redis.call("ZSCORE", dest, "2").to_f).to eq(10.0)
      expect(redis.call("ZSCORE", dest, "1").to_f).to be_within(0.001).of(8.1)
    end
  end
end
