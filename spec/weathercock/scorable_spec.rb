# frozen_string_literal: true

require "weathercock/scorable"

RSpec.describe Weathercock::Scorable do
  before do
    Timecop.freeze(Time.new(2026, 4, 15, 9, 0, 0))
    stub_const("Article", Class.new do
      include Weathercock::Scorable

      attr_reader :id

      def initialize(id) = @id = id
    end)
  end

  describe "#hit / #hit_count" do
    it "delegates to Scorer" do
      article = Article.new(42)
      article.hit(:views, increment: 3)
      expect(article.hit_count(:views)).to eq(3)
      expect(article.hit_count(:views, days: 7)).to eq(3)
    end
  end

  describe ".top" do
    it "delegates to Scorer" do
      Article.new(42).hit(:views, increment: 2)
      Article.new(7).hit(:views)
      expect(Article.top(:views, limit: 2)).to eq(["42", "7"])
    end
  end

  describe ".hit_counts" do
    it "delegates to Scorer" do
      Article.new(42).hit(:views, increment: 2)
      Article.new(7).hit(:views)
      result = Article.hit_counts(:views, ids: [42, 7])
      expect(result).to eq("42" => 2, "7" => 1)
    end
  end

  describe "#rank" do
    it "delegates to Scorer" do
      Article.new(42).hit(:views, increment: 2)
      Article.new(7).hit(:views)
      expect(Article.new(42).rank(:views)).to eq(1)
      expect(Article.new(7).rank(:views)).to eq(2)
      expect(Article.new(999).rank(:views)).to be_nil
    end
  end

  describe "#remove_hits" do
    it "delegates to Scorer" do
      article = Article.new(42)
      article.hit(:views)
      article.remove_hits(:views)
      expect(article.hit_count(:views)).to eq(0)
    end
  end

  describe ".weathercock_scorer" do
    it "returns a Scorer instance" do
      expect(Article.weathercock_scorer).to be_a(Weathercock::Scorer)
    end

    it "memoizes the instance" do
      expect(Article.weathercock_scorer).to be(Article.weathercock_scorer)
    end
  end
end
