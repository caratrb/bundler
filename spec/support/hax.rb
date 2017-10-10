# frozen_string_literal: true

require "rubygems"

module Gem
  if version = ENV["CARATR_SPEC_RUBYGEMS_VERSION"]
    remove_const(:VERSION) if const_defined?(:VERSION)
    VERSION = version
  end

  class Platform
    @local = new(ENV["CARATR_SPEC_PLATFORM"]) if ENV["CARATR_SPEC_PLATFORM"]
  end
  @platforms = [Gem::Platform::RUBY, Gem::Platform.local]
end

if ENV["CARATR_SPEC_VERSION"]
  module Carat
    remove_const(:VERSION) if const_defined?(:VERSION)
    VERSION = ENV["CARATR_SPEC_VERSION"].dup
  end
end

if ENV["CARATR_SPEC_WINDOWS"] == "true"
  require "carat/constants"

  module Carat
    remove_const :WINDOWS if defined?(WINDOWS)
    WINDOWS = true
  end
end

class Object
  if ENV["CARATR_SPEC_RUBY_ENGINE"]
    if defined?(RUBY_ENGINE) && RUBY_ENGINE != "jruby" && ENV["CARATR_SPEC_RUBY_ENGINE"] == "jruby"
      begin
        # this has to be done up front because psych will try to load a .jar
        # if it thinks its on jruby
        require "psych"
      rescue LoadError
        nil
      end
    end

    remove_const :RUBY_ENGINE if defined?(RUBY_ENGINE)
    RUBY_ENGINE = ENV["CARATR_SPEC_RUBY_ENGINE"]

    if RUBY_ENGINE == "jruby"
      remove_const :JRUBY_VERSION if defined?(JRUBY_VERSION)
      JRUBY_VERSION = ENV["CARATR_SPEC_RUBY_ENGINE_VERSION"]
    end
  end
end

if ENV["CARATR_SPEC_IGNORE_COMPATIBILITY_GUARD"]
  $LOADED_FEATURES << File.expand_path("../../../carat/compatibility_guard.rb", __FILE__)
  $LOADED_FEATURES << File.expand_path("../../../carat/compatibility_guard", __FILE__)
  $LOADED_FEATURES << "carat/compatibility_guard.rb"
  $LOADED_FEATURES << "carat/compatibility_guard"
  require "carat/compatibility_guard"
end
