# frozen_string_literal: true

require "date"
require_relative "../weathercock"

module Weathercock
  module Scorable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def top(event, hours: nil, days: nil, months: nil)
        redis = Weathercock.config.redis
        base = weathercock_base_key(event)
        now = Time.now

        keys = if hours
          hours.times.map { |i| "#{base}:#{(now - i * 3600).strftime("%Y-%m-%d-%H")}" }
        elsif days
          days.times.map { |i| "#{base}:#{(now - i * 86400).strftime("%Y-%m-%d")}" }
        elsif months
          d = Date.new(now.year, now.month)
          months.times.map { |i| "#{base}:#{(d << i).strftime("%Y-%m")}" }
        end

        dest = "#{base}:top"
        redis.call("ZUNIONSTORE", dest, keys.size, *keys)
        redis.call("EXPIRE", dest, 900)
        redis.call("ZREVRANGE", dest, 0, -1)
      end

      def weathercock_base_key(event)
        "#{Weathercock.config.namespace}:#{name.gsub("::", "_").downcase}:#{event}"
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
  end
end
