# frozen_string_literal: true

RSpec.describe "post carat message" do
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

  let(:carat_path)                { "./.carat" }
  let(:carat_show_system_message) { "Use `carat info [gemname]` to see where a carated gem is installed." }
  let(:carat_show_path_message)   { "Gems are installed into `#{carat_path}`" }
  let(:carat_complete_message)    { "Carat complete!" }
  let(:carat_updated_message)     { "Carat updated!" }
  let(:installed_gems_stats)       { "4 Gemfile dependencies, 5 gems now installed." }
  let(:carat_show_message)        { Carat::VERSION.split(".").first.to_i < 2 ? carat_show_system_message : carat_show_path_message }

  describe "for fresh carat install" do
    it "without any options" do
      carat :install
      expect(out).to include(carat_show_message)
      expect(out).not_to include("Gems in the group")
      expect(out).to include(carat_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without one group" do
      carat! :install, forgotten_command_line_options(:without => "emo")
      expect(out).to include(carat_show_message)
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(carat_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without two groups" do
      carat! :install, forgotten_command_line_options(:without => "emo test")
      expect(out).to include(carat_show_message)
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(carat_complete_message)
      expect(out).to include("4 Gemfile dependencies, 3 gems now installed.")
    end

    it "with --without more groups" do
      carat! :install, forgotten_command_line_options(:without => "emo obama test")
      expect(out).to include(carat_show_message)
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(carat_complete_message)
      expect(out).to include("4 Gemfile dependencies, 2 gems now installed.")
    end

    describe "with --path and" do
      let(:carat_path) { "./vendor" }

      it "without any options" do
        carat! :install, forgotten_command_line_options(:path => "vendor")
        expect(out).to include(carat_show_path_message)
        expect(out).to_not include("Gems in the group")
        expect(out).to include(carat_complete_message)
      end

      it "with --without one group" do
        carat! :install, forgotten_command_line_options(:without => "emo", :path => "vendor")
        expect(out).to include(carat_show_path_message)
        expect(out).to include("Gems in the group emo were not installed")
        expect(out).to include(carat_complete_message)
      end

      it "with --without two groups" do
        carat! :install, forgotten_command_line_options(:without => "emo test", :path => "vendor")
        expect(out).to include(carat_show_path_message)
        expect(out).to include("Gems in the groups emo and test were not installed")
        expect(out).to include(carat_complete_message)
      end

      it "with --without more groups" do
        carat! :install, forgotten_command_line_options(:without => "emo obama test", :path => "vendor")
        expect(out).to include(carat_show_path_message)
        expect(out).to include("Gems in the groups emo, obama and test were not installed")
        expect(out).to include(carat_complete_message)
      end

      it "with an absolute --path inside the cwd" do
        carat! :install, forgotten_command_line_options(:path => carated_app("cache"))
        expect(out).to include("Gems are installed into `./cache`")
        expect(out).to_not include("Gems in the group")
        expect(out).to include(carat_complete_message)
      end

      it "with an absolute --path outside the cwd" do
        carat! :install, forgotten_command_line_options(:path => tmp("not_carated_app"))
        expect(out).to include("Gems are installed into `#{tmp("not_carated_app")}`")
        expect(out).to_not include("Gems in the group")
        expect(out).to include(carat_complete_message)
      end
    end

    describe "with misspelled or non-existent gem name" do
      it "should report a helpful error message", :carat => "< 2" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
          gem "not-a-gem", :group => :development
        G
        expect(out).to include("Could not find gem 'not-a-gem' in any of the gem sources listed in your Gemfile.")
      end

      it "should report a helpful error message", :carat => "2" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
          gem "not-a-gem", :group => :development
        G
        expect(out).to include <<-EOS.strip
Could not find gem 'not-a-gem' in rubygems repository file:#{gem_repo1}/ or installed locally.
The source does not contain any versions of 'not-a-gem'
        EOS
      end

      it "should report a helpful error message with reference to cache if available" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
        G
        carat :cache
        expect(carated_app("vendor/cache/rack-1.0.0.gem")).to exist
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
          gem "not-a-gem", :group => :development
        G
        expect(out).to include("Could not find gem 'not-a-gem' in").
          and include("or in gems cached in vendor/cache.")
      end
    end
  end

  describe "for second carat install run" do
    it "without any options" do
      2.times { carat :install }
      expect(out).to include(carat_show_message)
      expect(out).to_not include("Gems in the groups")
      expect(out).to include(carat_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without one group" do
      carat! :install, forgotten_command_line_options(:without => "emo")
      carat! :install
      expect(out).to include(carat_show_message)
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(carat_complete_message)
      expect(out).to include(installed_gems_stats)
    end

    it "with --without two groups" do
      carat! :install, forgotten_command_line_options(:without => "emo test")
      carat! :install
      expect(out).to include(carat_show_message)
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(carat_complete_message)
    end

    it "with --without more groups" do
      carat! :install, forgotten_command_line_options(:without => "emo obama test")
      carat :install
      expect(out).to include(carat_show_message)
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(carat_complete_message)
    end
  end

  describe "for carat update" do
    it "without any options" do
      carat! :update, :all => carat_update_requires_all?
      expect(out).not_to include("Gems in the groups")
      expect(out).to include(carat_updated_message)
    end

    it "with --without one group" do
      carat! :install, forgotten_command_line_options(:without => "emo")
      carat! :update, :all => carat_update_requires_all?
      expect(out).to include("Gems in the group emo were not installed")
      expect(out).to include(carat_updated_message)
    end

    it "with --without two groups" do
      carat! :install, forgotten_command_line_options(:without => "emo test")
      carat! :update, :all => carat_update_requires_all?
      expect(out).to include("Gems in the groups emo and test were not installed")
      expect(out).to include(carat_updated_message)
    end

    it "with --without more groups" do
      carat! :install, forgotten_command_line_options(:without => "emo obama test")
      carat! :update, :all => carat_update_requires_all?
      expect(out).to include("Gems in the groups emo, obama and test were not installed")
      expect(out).to include(carat_updated_message)
    end
  end
end
