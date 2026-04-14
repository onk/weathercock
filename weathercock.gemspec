# frozen_string_literal: true

require_relative "lib/weathercock/version"

Gem::Specification.new do |spec|
  spec.name = "weathercock"
  spec.version = Weathercock::VERSION
  spec.authors = ["Takafumi ONAKA"]
  spec.email = ["takafumi.onaka@gmail.com"]

  spec.summary = "Hit counter and popularity tracking using Valkey/Redis Sorted Sets"
  spec.description = "Track hit counts for arbitrary resources and aggregate them with zunionstore to build popularity rankings across time windows."
  spec.homepage = "https://github.com/onk/weathercock"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/onk/weathercock"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "timecop"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
