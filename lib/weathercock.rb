# frozen_string_literal: true

require_relative "weathercock/version"

module Weathercock
  class Error < StandardError; end

  class Config
    attr_accessor :namespace, :redis

    def initialize
      @namespace = "weathercock"
    end
  end

  class << self
    def configure
      yield config
    end

    def config
      @config ||= Config.new
    end
  end
end
