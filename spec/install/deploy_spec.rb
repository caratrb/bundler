# frozen_string_literal: true

RSpec.describe "install with --deployment or --frozen" do
  before do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  context "with CLI flags", :carat => "< 2" do
    it "fails without a lockfile and says that --deployment requires a lock" do
      carat "install --deployment"
      expect(out).to include("The --deployment flag requires a Gemfile.lock")
    end

    it "fails without a lockfile and says that --frozen requires a lock" do
      carat "install --frozen"
      expect(out).to include("The --frozen flag requires a Gemfile.lock")
    end

    it "disallows --deployment --system" do
      carat "install --deployment --system"
      expect(out).to include("You have specified both --deployment")
      expect(out).to include("Please choose only one option")
      expect(exitstatus).to eq(15) if exitstatus
    end

    it "disallows --deployment --path --system" do
      carat "install --deployment --path . --system"
      expect(out).to include("You have specified both --path")
      expect(out).to include("as well as --system")
      expect(out).to include("Please choose only one option")
      expect(exitstatus).to eq(15) if exitstatus
    end

    it "works after you try to deploy without a lock" do
      carat "install --deployment"
      carat! :install
      expect(the_carat).to include_gems "rack 1.0"
    end
  end

  it "still works if you are not in the app directory and specify --gemfile" do
    carat "install"
    Dir.chdir tmp do
      simulate_new_machine
      carat! :install,
        forgotten_command_line_options(:gemfile => "#{tmp}/carated_app/Gemfile",
                                       :deployment => true,
                                       :path => "vendor/carat")
    end
    expect(the_carat).to include_gems "rack 1.0"
  end

  it "works if you exclude a group with a git gem" do
    build_git "foo"
    gemfile <<-G
      group :test do
        gem "foo", :git => "#{lib_path("foo-1.0")}"
      end
    G
    carat :install
    carat! :install, forgotten_command_line_options(:deployment => true, :without => "test")
  end

  it "works when you carat exec carat" do
    carat :install
    carat "install --deployment"
    carat! "exec carat check"
  end

  it "works when using path gems from the same path and the version is specified" do
    build_lib "foo", :path => lib_path("nested/foo")
    build_lib "bar", :path => lib_path("nested/bar")
    gemfile <<-G
      gem "foo", "1.0", :path => "#{lib_path("nested")}"
      gem "bar", :path => "#{lib_path("nested")}"
    G

    carat! :install
    carat! :install, forgotten_command_line_options(:deployment => true)
  end

  it "works when there are credentials in the source URL" do
    install_gemfile(<<-G, :artifice => "endpoint_strict_basic_authentication", :quiet => true)
      source "http://user:pass@localgemserver.test/"

      gem "rack-obama", ">= 1.0"
    G

    carat! :install, forgotten_command_line_options(:deployment => true).merge(:artifice => "endpoint_strict_basic_authentication")
  end

  it "works with sources given by a block" do
    install_gemfile! <<-G
      source "file://#{gem_repo1}" do
        gem "rack"
      end
    G

    carat! :install, forgotten_command_line_options(:deployment => true)

    expect(the_carat).to include_gems "rack 1.0"
  end

  describe "with an existing lockfile" do
    before do
      carat "install"
    end

    it "works with the --deployment flag if you didn't change anything", :carat => "< 2" do
      carat! "install --deployment"
    end

    it "works with the --frozen flag if you didn't change anything", :carat => "< 2" do
      carat! "install --frozen"
    end

    it "works with CARAT_FROZEN if you didn't change anything" do
      carat! :install, :env => { "CARAT_FROZEN" => "true" }
    end

    it "explodes with the --deployment flag if you make a change and don't check in the lockfile" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "rack-obama"
      G

      carat :install, forgotten_command_line_options(:deployment => true)
      expect(out).to include("deployment mode")
      expect(out).to include("You have added to the Gemfile")
      expect(out).to include("* rack-obama")
      expect(out).not_to include("You have deleted from the Gemfile")
      expect(out).not_to include("You have changed in the Gemfile")
    end

    it "works if a path gem is missing but is in a without group" do
      build_lib "path_gem"
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rake"
        gem "path_gem", :path => "#{lib_path("path_gem-1.0")}", :group => :development
      G
      expect(the_carat).to include_gems "path_gem 1.0"
      FileUtils.rm_r lib_path("path_gem-1.0")

      carat! :install, forgotten_command_line_options(:path => ".carat", :without => "development", :deployment => true).merge(:env => { :DEBUG => "1" })
      run! "puts :WIN"
      expect(out).to eq("WIN")
    end

    it "explodes if a path gem is missing" do
      build_lib "path_gem"
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rake"
        gem "path_gem", :path => "#{lib_path("path_gem-1.0")}", :group => :development
      G
      expect(the_carat).to include_gems "path_gem 1.0"
      FileUtils.rm_r lib_path("path_gem-1.0")

      carat :install, forgotten_command_line_options(:path => ".carat", :deployment => true)
      expect(out).to include("The path `#{lib_path("path_gem-1.0")}` does not exist.")
    end

    it "can have --frozen set via an environment variable", :carat => "< 2" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "rack-obama"
      G

      ENV["CARAT_FROZEN"] = "1"
      carat "install"
      expect(out).to include("deployment mode")
      expect(out).to include("You have added to the Gemfile")
      expect(out).to include("* rack-obama")
      expect(out).not_to include("You have deleted from the Gemfile")
      expect(out).not_to include("You have changed in the Gemfile")
    end

    it "can have --deployment set via an environment variable" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "rack-obama"
      G

      ENV["CARAT_DEPLOYMENT"] = "true"
      carat "install"
      expect(out).to include("deployment mode")
      expect(out).to include("You have added to the Gemfile")
      expect(out).to include("* rack-obama")
      expect(out).not_to include("You have deleted from the Gemfile")
      expect(out).not_to include("You have changed in the Gemfile")
    end

    it "can have --frozen set to false via an environment variable" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "rack-obama"
      G

      ENV["CARAT_FROZEN"] = "false"
      ENV["CARAT_DEPLOYMENT"] = "false"
      carat "install"
      expect(out).not_to include("deployment mode")
      expect(out).not_to include("You have added to the Gemfile")
      expect(out).not_to include("* rack-obama")
    end

    it "explodes with the --frozen flag if you make a change and don't check in the lockfile", :carat => "< 2" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "rack-obama", "1.1"
      G

      carat :install, forgotten_command_line_options(:frozen => true)
      expect(out).to include("deployment mode")
      expect(out).to include("You have added to the Gemfile")
      expect(out).to include("* rack-obama (= 1.1)")
      expect(out).not_to include("You have deleted from the Gemfile")
      expect(out).not_to include("You have changed in the Gemfile")
    end

    it "explodes if you remove a gem and don't check in the lockfile" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "activesupport"
      G

      carat :install, forgotten_command_line_options(:deployment => true)
      expect(out).to include("deployment mode")
      expect(out).to include("You have added to the Gemfile:\n* activesupport\n\n")
      expect(out).to include("You have deleted from the Gemfile:\n* rack")
      expect(out).not_to include("You have changed in the Gemfile")
    end

    it "explodes if you add a source" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "git://hubz.com"
      G

      carat :install, forgotten_command_line_options(:deployment => true)
      expect(out).to include("deployment mode")
      expect(out).to include("You have added to the Gemfile:\n* source: git://hubz.com (at master)")
      expect(out).not_to include("You have changed in the Gemfile")
    end

    it "explodes if you unpin a source" do
      build_git "rack"

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack-1.0")}"
      G

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat :install, forgotten_command_line_options(:deployment => true)
      expect(out).to include("deployment mode")
      expect(out).to include("You have deleted from the Gemfile:\n* source: #{lib_path("rack-1.0")} (at master@#{revision_for(lib_path("rack-1.0"))[0..6]}")
      expect(out).not_to include("You have added to the Gemfile")
      expect(out).not_to include("You have changed in the Gemfile")
    end

    it "explodes if you unpin a source, leaving it pinned somewhere else" do
      build_lib "foo", :path => lib_path("rack/foo")
      build_git "rack", :path => lib_path("rack")

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack")}"
        gem "foo", :git => "#{lib_path("rack")}"
      G

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
        gem "foo", :git => "#{lib_path("rack")}"
      G

      carat :install, forgotten_command_line_options(:deployment => true)
      expect(out).to include("deployment mode")
      expect(out).to include("You have changed in the Gemfile:\n* rack from `no specified source` to `#{lib_path("rack")} (at master@#{revision_for(lib_path("rack"))[0..6]})`")
      expect(out).not_to include("You have added to the Gemfile")
      expect(out).not_to include("You have deleted from the Gemfile")
    end

    context "when replacing a host with the same host with credentials" do
      let(:success_message) do
        if Carat::VERSION.split(".", 2).first == "1"
          "Could not reach host localgemserver.test"
        else
          "Carat complete!"
        end
      end

      before do
        install_gemfile <<-G
        source "http://user_name:password@localgemserver.test/"
        gem "rack"
        G

        lockfile <<-G
        GEM
          remote: http://localgemserver.test/
          specs:
            rack (1.0.0)

        PLATFORMS
          #{local}

        DEPENDENCIES
          rack
        G
      end

      it "prevents the replace by default" do
        carat :install, forgotten_command_line_options(:deployment => true)

        expect(out).to match(/The list of sources changed/)
      end

      context "when allow_deployment_source_credential_changes is true" do
        before { carat! "config allow_deployment_source_credential_changes true" }

        it "allows the replace" do
          carat :install, forgotten_command_line_options(:deployment => true)

          expect(out).to match(/#{success_message}/)
        end
      end

      context "when allow_deployment_source_credential_changes is false" do
        before { carat! "config allow_deployment_source_credential_changes false" }

        it "prevents the replace" do
          carat :install, forgotten_command_line_options(:deployment => true)

          expect(out).to match(/The list of sources changed/)
        end
      end

      context "when CARAT_ALLOW_DEPLOYMENT_SOURCE_CREDENTIAL_CHANGES env var is true" do
        before { ENV["CARAT_ALLOW_DEPLOYMENT_SOURCE_CREDENTIAL_CHANGES"] = "true" }

        it "allows the replace" do
          carat :install, forgotten_command_line_options(:deployment => true)

          expect(out).to match(/#{success_message}/)
        end
      end

      context "when CARAT_ALLOW_DEPLOYMENT_SOURCE_CREDENTIAL_CHANGES env var is false" do
        before { ENV["CARAT_ALLOW_DEPLOYMENT_SOURCE_CREDENTIAL_CHANGES"] = "false" }

        it "prevents the replace" do
          carat :install, forgotten_command_line_options(:deployment => true)

          expect(out).to match(/The list of sources changed/)
        end
      end
    end

    it "remembers that the carat is frozen at runtime" do
      carat! :lock

      carat! "config deployment true"

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", "1.0.0"
        gem "rack-obama"
      G

      expect(the_carat).not_to include_gems "rack 1.0.0"
      expect(err).to include strip_whitespace(<<-E).strip
The dependencies in your gemfile changed

You have added to the Gemfile:
* rack (= 1.0.0)
* rack-obama

You have deleted from the Gemfile:
* rack
      E
    end
  end

  context "with path in Gemfile and packed" do
    it "works fine after carat package and carat install --local" do
      build_lib "foo", :path => lib_path("foo")
      install_gemfile! <<-G
        gem "foo", :path => "#{lib_path("foo")}"
      G

      carat! :install
      expect(the_carat).to include_gems "foo 1.0"
      carat! :package, forgotten_command_line_options([:all, :cache_all] => true)
      expect(carated_app("vendor/cache/foo")).to be_directory

      carat! "install --local"
      expect(out).to include("Updating files in vendor/cache")

      simulate_new_machine
      carat! "install --verbose", forgotten_command_line_options(:deployment => true)
      expect(out).not_to include("You are trying to install in deployment mode after changing your Gemfile")
      expect(out).not_to include("You have added to the Gemfile")
      expect(out).not_to include("You have deleted from the Gemfile")
      expect(out).to include("vendor/cache/foo")
      expect(the_carat).to include_gems "foo 1.0"
    end
  end
end
