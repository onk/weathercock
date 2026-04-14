# frozen_string_literal: true

require "date"
require_relative "../weathercock"

module Weathercock
  module Scorable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def top(event, decay_factor: nil, **window)
        dest = weathercock_union(event, window, decay_factor: decay_factor)
        Weathercock.config.redis.call("ZREVRANGE", dest, 0, -1)
      end

      def hit_counts(event, ids:, **window)
        dest = weathercock_union(event, window)
        redis = Weathercock.config.redis
        ids.map { |id| [id.to_s, (redis.call("ZSCORE", dest, id.to_s) || "0").to_i] }.to_h
      end

      def weathercock_base_key(event)
        "#{Weathercock.config.namespace}:#{name.gsub("::", "_").downcase}:#{event}"
      end

      private

      def weathercock_union(event, window, decay_factor: nil)
        redis = Weathercock.config.redis
        base = weathercock_base_key(event)
        now = Time.now
        type, count = window.first

        keys = if type == :hours
          count.times.map { |i| "#{base}:#{(now - i * 3600).strftime("%Y-%m-%d-%H")}" }
        elsif type == :days
          count.times.map { |i| "#{base}:#{(now - i * 86400).strftime("%Y-%m-%d")}" }
        elsif type == :months
          d = Date.new(now.year, now.month)
          count.times.map { |i| "#{base}:#{(d << i).strftime("%Y-%m")}" }
        end

        dest = "#{base}:top:#{type}:#{count}"
        weights = decay_factor ? count.times.map { |i| (decay_factor**i).round(10) } : nil
        zunionstore_args = ["ZUNIONSTORE", dest, keys.size, *keys]
        zunionstore_args += ["WEIGHTS", *weights] if weights
        redis.call(*zunionstore_args)
        redis.call("EXPIRE", dest, 900)
        dest
      end
    end

    def hit(event, increment: 1)
      now = Time.now
      redis = Weathercock.config.redis
      base = self.class.weathercock_base_key(event)

      redis.pipelined do |p|
        p.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m-%d-%H")}", increment, id.to_s)
        p.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m-%d")}", increment, id.to_s)
        p.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m")}", increment, id.to_s)
      end
    end

    def hit_count(event, **window)
      dest = self.class.send(:weathercock_union, event, window)
      score = Weathercock.config.redis.call("ZSCORE", dest, id.to_s)
      score ? score.to_i : 0
    end
  end
end
