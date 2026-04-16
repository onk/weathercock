# frozen_string_literal: true

require_relative "key_builder"

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
      def top(event, limit:, decay_factor: nil, **window)
        redis = Weathercock.config.redis
        kb = KeyBuilder.new(namespace: Weathercock.config.namespace)
        stop = limit ? limit - 1 : -1
        return redis.call("ZRANGE", "#{kb.base(self, event)}:total", 0, stop, "REV") if window.empty?

        dest = kb.union(redis, self, event, window, decay_factor: decay_factor)
        redis.call("ZRANGE", dest, 0, stop, "REV")
      end

      def hit_counts(event, ids:, **window)
        redis = Weathercock.config.redis
        kb = KeyBuilder.new(namespace: Weathercock.config.namespace)
        base = kb.base(self, event)
        dest = window.empty? ? "#{base}:total" : kb.union(redis, self, event, window)
        ids.to_h { |id| [id.to_s, (redis.call("ZSCORE", dest, id.to_s) || "0").to_i] }
      end
    end

    def hit(event, increment: 1)
      now = Time.now
      redis = Weathercock.config.redis
      kb = KeyBuilder.new(namespace: Weathercock.config.namespace)
      base = kb.base(self.class, event)

      redis.pipelined do |p|
        p.call("ZINCRBY", "#{base}:total", increment, id.to_s)
        WEATHERCOCK_BUCKET_TTLS.each do |type, ttl|
          key = kb.bucket(base, type, now)
          p.call("ZINCRBY", key, increment, id.to_s)
          p.call("EXPIRE", key, ttl)
        end
      end
    end

    def hit_count(event, **window)
      redis = Weathercock.config.redis
      kb = KeyBuilder.new(namespace: Weathercock.config.namespace)
      base = kb.base(self.class, event)
      if window.empty?
        score = redis.call("ZSCORE", "#{base}:total", id.to_s)
        return score ? score.to_i : 0
      end

      dest = kb.union(redis, self.class, event, window)
      score = redis.call("ZSCORE", dest, id.to_s)
      score ? score.to_i : 0
    end
  end
end
