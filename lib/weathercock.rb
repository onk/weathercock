# frozen_string_literal: true

require_relative "weathercock/version"
require_relative "weathercock/key_builder"
require_relative "weathercock/scorer"
require_relative "weathercock/scorable"

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
