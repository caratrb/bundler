# frozen_string_literal: true

module Carat
  def self.require_thor_actions
    Kernel.send(:require, "carat/vendor/thor/lib/thor/actions")
  end
end
require "carat/vendor/thor/lib/thor"
