# frozen_string_literal: true

require "date"

module Weathercock
  class KeyBuilder
    def initialize(namespace:, klass:)
      @namespace = namespace
      @klass_key = klass.name.gsub("::", "_").downcase
    end

    def base(event)
      "#{@namespace}:#{@klass_key}:#{event}"
    end

    def total(base)
      "#{base}:total"
    end

    def bucket(base, type, time)
      case type
      when :hours  then "#{base}:#{time.strftime("%Y-%m-%d-%H")}"
      when :days   then "#{base}:#{time.strftime("%Y-%m-%d")}"
      when :months then "#{base}:#{time.strftime("%Y-%m")}"
      end
    end

    def window_keys(base, type, count)
      # Time.current (ActiveSupport) follows the app-configured time zone, so
      # bucket boundaries do not depend on each host's TZ setting.
      now = Time.respond_to?(:current) ? Time.current : Time.now # steep:ignore NoMethod
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

    def union_dest(base, type, count, decay_factor: nil)
      dest = "#{base}:top:#{type}:#{count}"
      decay_factor ? "#{dest}:decay:#{decay_factor}" : dest
    end
  end
end
