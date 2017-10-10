# frozen_string_literal: true

module Carat; end
if RUBY_VERSION >= "2.4"
  require "carat/vendor/fileutils/lib/fileutils"
else
  # the version we vendor is 2.4+
  require "fileutils"
end
