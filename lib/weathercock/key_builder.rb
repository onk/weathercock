# frozen_string_literal: true

require "date"

module Weathercock
  class KeyBuilder
    def initialize(namespace:)
      @namespace = namespace
    end

    def base(klass, event)
      "#{@namespace}:#{klass.name.gsub("::", "_").downcase}:#{event}"
    end

    def bucket(base, type, time)
      case type
      when :hours  then "#{base}:#{time.strftime("%Y-%m-%d-%H")}"
      when :days   then "#{base}:#{time.strftime("%Y-%m-%d")}"
      when :months then "#{base}:#{time.strftime("%Y-%m")}"
      end
    end

    def window_keys(base, type, count)
      now = Time.now
      case type
      when :hours
        count.times.map { |i| bucket(base, type, now - (i * 3600)) }
      when :days
        count.times.map { |i| bucket(base, type, now - (i * 86400)) }
      when :months
        d = Date.new(now.year, now.month)
        count.times.map { |i| bucket(base, type, d << i) }
      end
    end

    def union(redis, klass, event, window, decay_factor: nil)
      base = base(klass, event)
      type, count = window.first
      keys = window_keys(base, type, count)

      dest = "#{base}:top:#{type}:#{count}"
      weights = decay_factor ? count.times.map { |i| (decay_factor**i).round(10) } : nil
      zunionstore_args = ["ZUNIONSTORE", dest, keys.size, *keys]
      zunionstore_args += ["WEIGHTS", *weights] if weights
      redis.call(*zunionstore_args)
      redis.call("EXPIRE", dest, 900)
      dest
    end
  end
end
