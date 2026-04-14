# frozen_string_literal: true

require_relative "../weathercock"

module Weathercock
  module Scorable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def top(event, hours: nil, days: nil, months: nil)
        ns = Weathercock.config.namespace
        redis = Weathercock.config.redis
        model = name.gsub("::", "_").downcase
        now = Time.now

        keys = if hours
          hours.times.map { |i| "#{ns}:#{model}:#{event}:#{(now - i * 3600).strftime("%Y-%m-%d-%H")}" }
        elsif days
          days.times.map { |i| "#{ns}:#{model}:#{event}:#{(now - i * 86400).strftime("%Y-%m-%d")}" }
        elsif months
          months.times.map { |i| "#{ns}:#{model}:#{event}:#{(now << i).strftime("%Y-%m")}" }
        end

        dest = "#{ns}:#{model}:#{event}:top"
        redis.call("ZUNIONSTORE", dest, keys.size, *keys)
        redis.call("ZREVRANGE", dest, 0, -1)
      end
    end

    def hit(event, increment: 1)
      now = Time.now
      ns = Weathercock.config.namespace
      redis = Weathercock.config.redis
      base = "#{ns}:#{self.class.name.gsub("::", "_").downcase}:#{event}"

      redis.pipelined do |p|
        p.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m-%d-%H")}", increment, id.to_s)
        p.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m-%d")}", increment, id.to_s)
        p.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m")}", increment, id.to_s)
      end
    end
  end
end
