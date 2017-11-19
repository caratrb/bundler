require 'spec_helper'

describe "post bundle message" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
      gem "activesupport", "2.3.5", :group => [:emo, :test]
      group :test do
        gem "rspec"
      end
      gem "rack-obama", :group => :obama
    G
  end

  let(:bundle_show_message)       {"Use `carat show [gemname]` to see where a bundled gem is installed."}
  let(:bundle_deployment_message) {"Bundled gems are installed into ./vendor"}
  let(:bundle_complete_message)   {"Bundle complete!"}
  let(:bundle_updated_message)    {"Bundle updated!"}
  let(:installed_gems_stats)      {"4 Gemfile dependencies, 5 gems now installed."}

  describe "for fresh carat install" do
    it "without any options" do
      carat :install
      expect(out).to include(bundle_show_message)
      expect(out).not_to include("Gems in the group")
      expect(out).to include(bundle_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without one group" do
      carat "install --without emo"
      expect(out).to include(bundle_show_message)
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(bundle_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without two groups" do
      carat "install --without emo test"
      expect(out).to include(bundle_show_message)
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(bundle_complete_message)
      expect(out).to include("4 Gemfile dependencies, 3 gems now installed.")
    end

    it "with --without more groups" do
      carat "install --without emo obama test"
      expect(out).to include(bundle_show_message)
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(bundle_complete_message)
      expect(out).to include("4 Gemfile dependencies, 2 gems now installed.")
    end

    describe "with --path and" do
      it "without any options" do
        carat "install --path vendor"
        expect(out).to include(bundle_deployment_message)
        expect(out).to_not include("Gems in the group")
        expect(out).to include(bundle_complete_message)
      end

      it "with --without one group" do
        carat "install --without emo --path vendor"
        expect(out).to include(bundle_deployment_message)
        expect(out).to include("Gems in the group emo were not installed")
        expect(out).to include(bundle_complete_message)
      end

      it "with --without two groups" do
        carat "install --without emo test --path vendor"
        expect(out).to include(bundle_deployment_message)
        expect(out).to include("Gems in the groups emo and test were not installed")
        expect(out).to include(bundle_complete_message)
      end

      it "with --without more groups" do
        carat "install --without emo obama test --path vendor"
        expect(out).to include(bundle_deployment_message)
        expect(out).to include("Gems in the groups emo, obama and test were not installed")
        expect(out).to include(bundle_complete_message)
      end
    end

    describe "with misspelled or non-existent gem name" do
      before :each do
        gemfile <<-G
          source 'https://rubygems.org/'
          gem "rails"
          gem "misspelled-gem-name", :group => :development
        G
      end

      it "should report a helpufl error message" do
        carat :install
        expect(out).to include("Fetching gem metadata from https://rubygems.org/")
        expect(out).to include("Could not find gem 'misspelled-gem-name (>= 0) ruby' in any of the gem sources listed in your Gemfile or installed on this machine.")
      end
    end
  end

  describe "for second carat install run" do
    it "without any options" do
      2.times { carat :install }
      expect(out).to include(bundle_show_message)
      expect(out).to_not include("Gems in the groups")
      expect(out).to include(bundle_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without one group" do
      carat "install --without emo"
      carat :install
      expect(out).to include(bundle_show_message)
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(bundle_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without two groups" do
      carat "install --without emo test"
      carat :install
      expect(out).to include(bundle_show_message)
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(bundle_complete_message)
    end

    it "with --without more groups" do
      carat "install --without emo obama test"
      carat :install
      expect(out).to include(bundle_show_message)
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(bundle_complete_message)
    end
  end

  describe "for carat update" do
    it "without any options" do
      carat :update
      expect(out).not_to include("Gems in the groups")
      expect(out).to include(bundle_updated_message)
    end

    it "with --without one group" do
      carat :install, :without => :emo
      carat :update
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(bundle_updated_message)
    end

    it "with --without two groups" do
      carat "install --without emo test"
      carat :update
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(bundle_updated_message)
    end

    it "with --without more groups" do
      carat "install --without emo obama test"
      carat :update
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(bundle_updated_message)
    end
  end
end
