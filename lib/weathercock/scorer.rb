# frozen_string_literal: true

module Weathercock
  class Scorer
    BUCKET_TTLS = {
      hours: 3 * 24 * 3600,
      days: 3 * 30 * 86400,
      months: 3 * 12 * 30 * 86400
    }.freeze

    def initialize(redis: Weathercock.config.redis, namespace: Weathercock.config.namespace)
      @redis = redis
      @key_builder = KeyBuilder.new(namespace: namespace)
    end

    def hit(klass, id, event, increment: 1)
      now = Time.now
      base = @key_builder.base(klass, event)

      @redis.pipelined do |p|
        p.call("ZINCRBY", "#{base}:total", increment, id.to_s)
        BUCKET_TTLS.each do |type, ttl|
          key = @key_builder.bucket(base, type, now)
          p.call("ZINCRBY", key, increment, id.to_s)
          p.call("EXPIRE", key, ttl)
        end
      end
    end

    def hit_count(klass, id, event, **window)
      base = @key_builder.base(klass, event)
      if window.empty?
        score = @redis.call("ZSCORE", "#{base}:total", id.to_s)
        return score ? score.to_i : 0
      end

      dest = union(klass, event, window)
      score = @redis.call("ZSCORE", dest, id.to_s)
      score ? score.to_i : 0
    end

    def top(klass, event, limit:, decay_factor: nil, **window)
      base = @key_builder.base(klass, event)
      stop = limit ? limit - 1 : -1
      return @redis.call("ZRANGE", "#{base}:total", 0, stop, "REV") if window.empty?

      dest = union(klass, event, window, decay_factor: decay_factor)
      @redis.call("ZRANGE", dest, 0, stop, "REV")
    end

    def hit_counts(klass, event, ids:, **window)
      base = @key_builder.base(klass, event)
      dest = window.empty? ? "#{base}:total" : union(klass, event, window)
      ids.to_h { |id| [id.to_s, (@redis.call("ZSCORE", dest, id.to_s) || "0").to_i] }
    end

    private

    def union(klass, event, window, decay_factor: nil)
      base = @key_builder.base(klass, event)
      type, count = window.first
      keys = @key_builder.window_keys(base, type, count)
      dest = @key_builder.union_dest(base, type, count)

      weights = decay_factor ? count.times.map { |i| (decay_factor**i).round(10) } : nil
      zunionstore_args = ["ZUNIONSTORE", dest, keys.size, *keys]
      zunionstore_args += ["WEIGHTS", *weights] if weights
      @redis.call(*zunionstore_args)
      @redis.call("EXPIRE", dest, 900)
      dest
    end
  end
end
