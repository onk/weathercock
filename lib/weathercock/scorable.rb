# frozen_string_literal: true

require "date"
require_relative "../weathercock"

module Weathercock
  module Scorable
    WEATHERCOCK_BUCKET_TTLS = {
      hours: 3 * 24 * 3600,
      days: 3 * 30 * 86400,
      months: 3 * 12 * 30 * 86400
    }.freeze

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def top(event, decay_factor: nil, **window)
        dest = weathercock_union(event, window, decay_factor: decay_factor)
        Weathercock.config.redis.call("ZRANGE", dest, 0, -1, "REV")
      end

      def hit_counts(event, ids:, **window)
        dest = weathercock_union(event, window)
        redis = Weathercock.config.redis
        ids.to_h { |id| [id.to_s, (redis.call("ZSCORE", dest, id.to_s) || "0").to_i] }
      end

      def weathercock_base_key(event)
        "#{Weathercock.config.namespace}:#{name.gsub("::", "_").downcase}:#{event}"
      end

      private

      def weathercock_union(event, window, decay_factor: nil)
        redis = Weathercock.config.redis
        base = weathercock_base_key(event)
        type, count = window.first
        keys = weathercock_window_keys(base, type, count)

        dest = "#{base}:top:#{type}:#{count}"
        weights = decay_factor ? count.times.map { |i| (decay_factor**i).round(10) } : nil
        zunionstore_args = ["ZUNIONSTORE", dest, keys.size, *keys]
        zunionstore_args += ["WEIGHTS", *weights] if weights
        redis.call(*zunionstore_args)
        redis.call("EXPIRE", dest, 900)
        dest
      end

      def weathercock_window_keys(base, type, count)
        now = Time.now
        case type
        when :hours
          count.times.map { |i| weathercock_bucket_key(base, type, now - (i * 3600)) }
        when :days
          count.times.map { |i| weathercock_bucket_key(base, type, now - (i * 86400)) }
        when :months
          d = Date.new(now.year, now.month)
          count.times.map { |i| weathercock_bucket_key(base, type, d << i) }
        end
      end

      def weathercock_bucket_key(base, type, time)
        case type
        when :hours  then "#{base}:#{time.strftime("%Y-%m-%d-%H")}"
        when :days   then "#{base}:#{time.strftime("%Y-%m-%d")}"
        when :months then "#{base}:#{time.strftime("%Y-%m")}"
        end
      end
    end

    def hit(event, increment: 1)
      now = Time.now
      redis = Weathercock.config.redis
      base = self.class.weathercock_base_key(event)

      redis.pipelined do |p|
        WEATHERCOCK_BUCKET_TTLS.each do |type, ttl|
          key = self.class.send(:weathercock_bucket_key, base, type, now)
          p.call("ZINCRBY", key, increment, id.to_s)
          p.call("EXPIRE", key, ttl)
        end
      end
    end

    def hit_count(event, **window)
      dest = self.class.send(:weathercock_union, event, window)
      score = Weathercock.config.redis.call("ZSCORE", dest, id.to_s)
      score ? score.to_i : 0
    end
  end
end
