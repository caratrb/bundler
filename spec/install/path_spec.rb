# frozen_string_literal: true

RSpec.describe "carat install" do
  describe "with --path" do
    before :each do
      build_gem "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "puts 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    it "does not use available system gems with carat --path vendor/carat", :carat => "< 2" do
      carat! :install, forgotten_command_line_options(:path => "vendor/carat")
      expect(the_carat).to include_gems "rack 1.0.0"
    end

    it "handles paths with regex characters in them" do
      dir = carated_app("bun++dle")
      dir.mkpath

      Dir.chdir(dir) do
        carat! :install, forgotten_command_line_options(:path => dir.join("vendor/carat"))
        expect(out).to include("installed into `./vendor/carat`")
      end

      dir.rmtree
    end

    it "prints a warning to let the user know what has happened with carat --path vendor/carat" do
      carat! :install, forgotten_command_line_options(:path => "vendor/carat")
      expect(out).to include("gems are installed into `./vendor/carat`")
    end

    it "disallows --path vendor/carat --system", :carat => "< 2" do
      carat "install --path vendor/carat --system"
      expect(out).to include("Please choose only one option.")
      expect(exitstatus).to eq(15) if exitstatus
    end

    it "remembers to disable system gems after the first time with carat --path vendor/carat", :carat => "< 2" do
      carat "install --path vendor/carat"
      FileUtils.rm_rf carated_app("vendor")
      carat "install"

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      expect(the_carat).to include_gems "rack 1.0.0"
    end

    context "with path_relative_to_cwd set to true" do
      before { carat! "config path_relative_to_cwd true" }

      it "installs the carat relatively to current working directory", :carat => "< 2" do
        Dir.chdir(carated_app.parent) do
          carat! "install --gemfile='#{carated_app}/Gemfile' --path vendor/carat"
          expect(out).to include("installed into `./vendor/carat`")
          expect(carated_app("../vendor/carat")).to be_directory
        end
        expect(the_carat).to include_gems "rack 1.0.0"
      end

      it "installs the standalone carat relative to the cwd" do
        Dir.chdir(carated_app.parent) do
          carat! :install, :gemfile => carated_app("Gemfile"), :standalone => true
          expect(out).to include("installed into `./carated_app/carat`")
          expect(carated_app("carat")).to be_directory
          expect(carated_app("carat/ruby")).to be_directory
        end

        carat! "config unset path"

        Dir.chdir(carated_app("subdir").tap(&:mkpath)) do
          carat! :install, :gemfile => carated_app("Gemfile"), :standalone => true
          expect(out).to include("installed into `../carat`")
          expect(carated_app("carat")).to be_directory
          expect(carated_app("carat/ruby")).to be_directory
        end
      end
    end
  end

  describe "when CARAT_PATH or the global path config is set" do
    before :each do
      build_lib "rack", "1.0.0", :to_system => true do |s|
        s.write "lib/rack.rb", "raise 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    def set_carat_path(type, location)
      if type == :env
        ENV["CARAT_PATH"] = location
      elsif type == :global
        carat "config path #{location}", "no-color" => nil
      end
    end

    [:env, :global].each do |type|
      it "installs gems to a path if one is specified" do
        set_carat_path(type, carated_app("vendor2").to_s)
        carat! :install, forgotten_command_line_options(:path => "vendor/carat")

        expect(vendored_gems("gems/rack-1.0.0")).to be_directory
        expect(carated_app("vendor2")).not_to be_directory
        expect(the_carat).to include_gems "rack 1.0.0"
      end

      it "installs gems to CARAT_PATH with #{type}" do
        set_carat_path(type, carated_app("vendor").to_s)

        carat :install

        expect(carated_app("vendor/gems/rack-1.0.0")).to be_directory
        expect(the_carat).to include_gems "rack 1.0.0"
      end

      it "installs gems to CARAT_PATH relative to root when relative" do
        set_carat_path(type, "vendor")

        FileUtils.mkdir_p carated_app("lol")
        Dir.chdir(carated_app("lol")) do
          carat :install
        end

        expect(carated_app("vendor/gems/rack-1.0.0")).to be_directory
        expect(the_carat).to include_gems "rack 1.0.0"
      end
    end

    it "installs gems to CARAT_PATH from .carat/config" do
      config "CARAT_PATH" => carated_app("vendor/carat").to_s

      carat :install

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      expect(the_carat).to include_gems "rack 1.0.0"
    end

    it "sets CARAT_PATH as the first argument to carat install" do
      carat! :install, forgotten_command_line_options(:path => "./vendor/carat")

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      expect(the_carat).to include_gems "rack 1.0.0"
    end

    it "disables system gems when passing a path to install" do
      # This is so that vendored gems can be distributed to others
      build_gem "rack", "1.1.0", :to_system => true
      carat! :install, forgotten_command_line_options(:path => "./vendor/carat")

      expect(vendored_gems("gems/rack-1.0.0")).to be_directory
      expect(the_carat).to include_gems "rack 1.0.0"
    end

    it "re-installs gems whose extensions have been deleted", :rubygems => ">= 2.3" do
      build_lib "very_simple_binary", "1.0.0", :to_system => true do |s|
        s.write "lib/very_simple_binary.rb", "raise 'FAIL'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "very_simple_binary"
      G

      carat! :install, forgotten_command_line_options(:path => "./vendor/carat")

      expect(vendored_gems("gems/very_simple_binary-1.0")).to be_directory
      expect(vendored_gems("extensions")).to be_directory
      expect(the_carat).to include_gems "very_simple_binary 1.0", :source => "remote1"

      vendored_gems("extensions").rmtree

      run "require 'very_simple_binary_c'"
      expect(err).to include("Carat::GemNotFound")

      carat :install, forgotten_command_line_options(:path => "./vendor/carat")

      expect(vendored_gems("gems/very_simple_binary-1.0")).to be_directory
      expect(vendored_gems("extensions")).to be_directory
      expect(the_carat).to include_gems "very_simple_binary 1.0", :source => "remote1"
    end
  end

  describe "to a file" do
    before do
      in_app_root do
        `touch /tmp/idontexist carat`
      end
    end

    it "reports the file exists" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat :install, forgotten_command_line_options(:path => "carat")
      expect(out).to match(/file already exists/)
    end
  end
end
