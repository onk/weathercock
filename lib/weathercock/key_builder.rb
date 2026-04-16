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

    def union_dest(base, type, count)
      "#{base}:top:#{type}:#{count}"
    end
  end
end
