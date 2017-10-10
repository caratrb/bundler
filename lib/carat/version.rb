# frozen_string_literal: false

# Ruby 1.9.3 and old RubyGems don't play nice with frozen version strings
# rubocop:disable MutableConstant

module Carat
  # We're doing this because we might write tests that deal
  # with other versions of carat and we are unsure how to
  # handle this better.
  VERSION = "2.0.0.dev" unless defined?(::Carat::VERSION)

  def self.overwrite_loaded_gem_version
    begin
      require "rubygems"
    rescue LoadError
      return
    end
    return unless carat_spec = Gem.loaded_specs["carat"]
    return if carat_spec.version == VERSION
    carat_spec.version = Carat::VERSION
  end
  private_class_method :overwrite_loaded_gem_version
  overwrite_loaded_gem_version

  def self.carat_major_version
    @carat_major_version ||= VERSION.split(".").first.to_i
  end
end
