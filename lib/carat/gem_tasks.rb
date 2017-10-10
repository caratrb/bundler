# frozen_string_literal: true

require "rake/clean"
CLOBBER.include "pkg"

require "carat/gem_helper"
Carat::GemHelper.install_tasks
