# frozen_string_literal: true

require "weathercock/key_builder"

RSpec.describe Weathercock::KeyBuilder do
  let(:kb) { described_class.new(namespace: "wc") }

  before do
    Timecop.freeze(Time.new(2026, 4, 15, 9, 0, 0))
    stub_const("Blog::Article", Class.new)
  end

  let(:klass) { Blog::Article }

  describe "#base" do
    it "builds key with namespace and underscored class name" do
      expect(kb.base(klass, :views)).to eq("wc:blog_article:views")
    end
  end

  describe "#bucket" do
    let(:base) { "wc:blog_article:views" }
    let(:time) { Time.new(2026, 4, 15, 9, 0, 0) }

    it "builds hourly bucket key" do
      expect(kb.bucket(base, :hours, time)).to eq("wc:blog_article:views:2026-04-15-09")
    end

    it "builds daily bucket key" do
      expect(kb.bucket(base, :days, time)).to eq("wc:blog_article:views:2026-04-15")
    end

    it "builds monthly bucket key" do
      expect(kb.bucket(base, :months, time)).to eq("wc:blog_article:views:2026-04")
    end
  end

  describe "#window_keys" do
    let(:base) { "wc:blog_article:views" }

    it "returns hourly keys from newest to oldest" do
      keys = kb.window_keys(base, :hours, 3)
      expect(keys).to eq([
        "wc:blog_article:views:2026-04-15-09",
        "wc:blog_article:views:2026-04-15-08",
        "wc:blog_article:views:2026-04-15-07"
      ])
    end

    it "returns daily keys from newest to oldest" do
      keys = kb.window_keys(base, :days, 3)
      expect(keys).to eq([
        "wc:blog_article:views:2026-04-15",
        "wc:blog_article:views:2026-04-14",
        "wc:blog_article:views:2026-04-13"
      ])
    end

    it "returns monthly keys from newest to oldest" do
      keys = kb.window_keys(base, :months, 3)
      expect(keys).to eq([
        "wc:blog_article:views:2026-04",
        "wc:blog_article:views:2026-03",
        "wc:blog_article:views:2026-02"
      ])
    end
  end
end
