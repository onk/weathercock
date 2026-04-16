# frozen_string_literal: true

module Weathercock
  class Scorer
    BUCKET_TTLS = {
      hours: 3 * 24 * 3600,
      days: 3 * 30 * 86400,
      months: 3 * 12 * 30 * 86400
    }.freeze

    def initialize(klass:)
      @redis = Weathercock.config.redis
      @key_builder = KeyBuilder.new(namespace: Weathercock.config.namespace, klass: klass)
    end

    def hit(id, event, increment: 1)
      now = Time.now
      base = @key_builder.base(event)

      @redis.pipelined do |p|
        p.call("ZINCRBY", @key_builder.total(base), increment, id.to_s)
        BUCKET_TTLS.each do |type, ttl|
          key = @key_builder.bucket(base, type, now)
          p.call("ZINCRBY", key, increment, id.to_s)
          p.call("EXPIRE", key, ttl)
        end
      end
    end

    def hit_count(id, event, **window)
      base = @key_builder.base(event)
      if window.empty?
        score = @redis.call("ZSCORE", @key_builder.total(base), id.to_s)
        return score ? score.to_i : 0
      end

      dest = union(event, window)
      score = @redis.call("ZSCORE", dest, id.to_s)
      score ? score.to_i : 0
    end

    def top(event, limit:, decay_factor: nil, **window)
      base = @key_builder.base(event)
      stop = limit ? limit - 1 : -1
      return @redis.call("ZRANGE", @key_builder.total(base), 0, stop, "REV") if window.empty?

      dest = union(event, window, decay_factor: decay_factor)
      @redis.call("ZRANGE", dest, 0, stop, "REV")
    end

    def hit_counts(event, ids:, **window)
      base = @key_builder.base(event)
      dest = window.empty? ? @key_builder.total(base) : union(event, window)
      scores = @redis.call("ZMSCORE", dest, *ids.map(&:to_s))
      ids.zip(scores).to_h { |id, score| [id.to_s, (score || "0").to_i] }
    end

    private

    def union(event, window, decay_factor: nil)
      base = @key_builder.base(event)
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
