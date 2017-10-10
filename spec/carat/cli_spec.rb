# frozen_string_literal: true

require "carat/cli"

RSpec.describe "carat executable" do
  it "returns non-zero exit status when passed unrecognized options" do
    carat "--invalid_argument"
    expect(exitstatus).to_not be_zero if exitstatus
  end

  it "returns non-zero exit status when passed unrecognized task" do
    carat "unrecognized-task"
    expect(exitstatus).to_not be_zero if exitstatus
  end

  it "looks for a binary and executes it if it's named carat-<task>" do
    File.open(tmp("carat-testtasks"), "w", 0o755) do |f|
      f.puts "#!/usr/bin/env ruby\nputs 'Hello, world'\n"
    end

    with_path_added(tmp) do
      carat "testtasks"
    end

    expect(exitstatus).to be_zero if exitstatus
    expect(out).to eq("Hello, world")
  end

  context "with no arguments" do
    it "prints a concise help message", :carat => "2" do
      carat! ""
      expect(last_command.stderr).to be_empty
      expect(last_command.stdout).to include("Carat version #{Carat::VERSION}").
        and include("\n\nCarat commands:\n\n").
        and include("\n\n  Primary commands:\n").
        and include("\n\n  Utilities:\n").
        and include("\n\nOptions:\n")
    end
  end

  context "when ENV['CARAT_GEMFILE'] is set to an empty string" do
    it "ignores it" do
      gemfile carated_app("Gemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      carat :install, :env => { "CARAT_GEMFILE" => "" }

      expect(the_carat).to include_gems "rack 1.0.0"
    end
  end

  context "when ENV['RUBYGEMS_GEMDEPS'] is set" do
    it "displays a warning" do
      gemfile carated_app("Gemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      carat :install, :env => { "RUBYGEMS_GEMDEPS" => "foo" }
      expect(out).to include("RUBYGEMS_GEMDEPS")
      expect(out).to include("conflict with Carat")

      carat :install, :env => { "RUBYGEMS_GEMDEPS" => "" }
      expect(out).not_to include("RUBYGEMS_GEMDEPS")
    end
  end

  context "with --verbose" do
    it "prints the running command" do
      gemfile ""
      carat! "info carat", :verbose => true
      expect(last_command.stdout).to start_with("Running `carat info carat --no-color --verbose` with carat #{Carat::VERSION}")
    end

    it "doesn't print defaults" do
      install_gemfile! "", :verbose => true
      expect(last_command.stdout).to start_with("Running `carat install --no-color --retry 0 --verbose` with carat #{Carat::VERSION}")
    end

    it "doesn't print defaults" do
      install_gemfile! "", :verbose => true
      expect(last_command.stdout).to start_with("Running `carat install --no-color --retry 0 --verbose` with carat #{Carat::VERSION}")
    end
  end

  describe "printing the outdated warning" do
    shared_examples_for "no warning" do
      it "prints no warning" do
        carat "fail"
        expect(last_command.stdboth).to eq("Could not find command \"fail\".")
      end
    end

    let(:carat_version) { "1.1" }
    let(:latest_version) { nil }
    before do
      carat! "config --global disable_version_check false"

      simulate_carat_version(carat_version)
      if latest_version
        info_path = home(".carat/cache/compact_index/rubygems.org.443.29b0360b937aa4d161703e6160654e47/info/carat")
        info_path.parent.mkpath
        info_path.open("w") {|f| f.write "#{latest_version}\n" }
      end
    end

    context "when there is no latest version" do
      include_examples "no warning"
    end

    context "when the latest version is equal to the current version" do
      let(:latest_version) { carat_version }
      include_examples "no warning"
    end

    context "when the latest version is less than the current version" do
      let(:latest_version) { "0.9" }
      include_examples "no warning"
    end

    context "when the latest version is greater than the current version" do
      let(:latest_version) { "222.0" }
      it "prints the version warning" do
        carat "fail"
        expect(last_command.stdout).to start_with(<<-EOS.strip)
The latest carat is #{latest_version}, but you are currently running #{carat_version}.
To install the latest version, run `gem install carat`
        EOS
      end

      context "and disable_version_check is set" do
        before { carat! "config disable_version_check true" }
        include_examples "no warning"
      end

      context "running a parseable command" do
        it "prints no warning" do
          carat! "config --parseable foo"
          expect(last_command.stdboth).to eq ""

          carat "platform --ruby"
          expect(last_command.stdboth).to eq "Could not locate Gemfile"
        end
      end

      context "and is a pre-release" do
        let(:latest_version) { "222.0.0.pre.4" }
        it "prints the version warning" do
          carat "fail"
          expect(last_command.stdout).to start_with(<<-EOS.strip)
The latest carat is #{latest_version}, but you are currently running #{carat_version}.
To install the latest version, run `gem install carat --pre`
          EOS
        end
      end
    end
  end
end

RSpec.describe "carat executable" do
  it "shows the carat version just as the `carat` executable does", :carat => "< 2" do
    carat "--version"
    expect(out).to eq("Carat version #{Carat::VERSION}")
  end

  it "shows the carat version just as the `carat` executable does", :carat => "2" do
    carat "--version"
    expect(out).to eq(Carat::VERSION)
  end
end
