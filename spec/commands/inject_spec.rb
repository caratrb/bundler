require 'spec_helper'

describe "carat inject" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  context "without a lockfile" do
    it "locks with the injected gems" do
      expect(bundled_app("Gemfile.lock")).not_to exist
      carat "inject 'rack-obama' '> 0'"
      expect(bundled_app("Gemfile.lock").read).to match(/rack-obama/)
    end
  end

  context "with a lockfile" do
    before do
      carat "install"
    end

    it "adds the injected gems to the Gemfile" do
      expect(bundled_app("Gemfile").read).not_to match(/rack-obama/)
      carat "inject 'rack-obama' '> 0'"
      expect(bundled_app("Gemfile").read).to match(/rack-obama/)
    end

    it "locks with the injected gems" do
      expect(bundled_app("Gemfile.lock").read).not_to match(/rack-obama/)
      carat "inject 'rack-obama' '> 0'"
      expect(bundled_app("Gemfile.lock").read).to match(/rack-obama/)
    end
  end

  context "with injected gems already in the Gemfile" do
    it "doesn't add existing gems" do
      carat "inject 'rack' '> 0'"
      expect(out).to match(/cannot specify the same gem twice/i)
    end
  end

  context "when frozen" do
    before do
      carat "install"
      carat "config --local frozen 1"
    end

    it "injects anyway" do
      carat "inject 'rack-obama' '> 0'"
      expect(bundled_app("Gemfile").read).to match(/rack-obama/)
    end

    it "locks with the injected gems" do
      expect(bundled_app("Gemfile.lock").read).not_to match(/rack-obama/)
      carat "inject 'rack-obama' '> 0'"
      expect(bundled_app("Gemfile.lock").read).to match(/rack-obama/)
    end

    it "restores frozen afterwards" do
      carat "inject 'rack-obama' '> 0'"
      config = YAML.load(bundled_app(".carat/config").read)
      expect(config["BUNDLE_FROZEN"]).to eq("1")
    end

    it "doesn't allow Gemfile changes" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack-obama"
      G
      carat "inject 'rack' '> 0'"
      expect(out).to match(/trying to install in deployment mode after changing/)

      expect(bundled_app("Gemfile.lock").read).not_to match(/rack-obama/)
    end
  end
end
