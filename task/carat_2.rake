# frozen_string_literal: true

namespace :carat_2 do
  task :install do
    ENV["CARAT_SPEC_SUB_VERSION"] = "2.0.0.dev"
    Rake::Task["override_version"].invoke
    Rake::Task["install"].invoke
    sh("git", "checkout", "--", "lib/carat/version.rb")
  end
end
