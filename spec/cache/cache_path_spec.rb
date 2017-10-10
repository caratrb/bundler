# frozen_string_literal: true

RSpec.describe "carat package" do
  before do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  context "with --cache-path" do
    it "caches gems at given path" do
      carat :package, "cache-path" => "vendor/cache-foo"
      expect(carated_app("vendor/cache-foo/rack-1.0.0.gem")).to exist
    end
  end

  context "with config cache_path" do
    it "caches gems at given path" do
      carat "config cache_path vendor/cache-foo"
      carat :package
      expect(carated_app("vendor/cache-foo/rack-1.0.0.gem")).to exist
    end
  end

  context "with absolute --cache-path" do
    it "caches gems at given path" do
      carat :package, "cache-path" => "/tmp/cache-foo"
      expect(carated_app("/tmp/cache-foo/rack-1.0.0.gem")).to exist
    end
  end
end
