# frozen_string_literal: true

require_relative "../weathercock"

module Weathercock
  module Scorable
    def hit(event, increment: 1)
      now = Time.now
      ns = Weathercock.config.namespace
      redis = Weathercock.config.redis
      base = "#{ns}:#{self.class.name.gsub("::", "_").downcase}:#{event}"

      redis.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m-%d-%H")}", increment, id.to_s)
      redis.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m-%d")}", increment, id.to_s)
      redis.call("ZINCRBY", "#{base}:#{now.strftime("%Y-%m")}", increment, id.to_s)
    end
  end
end
