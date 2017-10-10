# frozen_string_literal: true

RSpec.describe "Running bin/* commands" do
  before :each do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  it "runs the carated command when in the carat" do
    carat! "binstubs rack"

    build_gem "rack", "2.0", :to_system => true do |s|
      s.executables = "rackup"
    end

    gembin "rackup"
    expect(out).to eq("1.0.0")
  end

  it "allows the location of the gem stubs to be specified" do
    carat! "binstubs rack", :path => "gbin"

    expect(carated_app("bin")).not_to exist
    expect(carated_app("gbin/rackup")).to exist

    gembin carated_app("gbin/rackup")
    expect(out).to eq("1.0.0")
  end

  it "allows absolute paths as a specification of where to install bin stubs" do
    carat! "binstubs rack", :path => tmp("bin")

    gembin tmp("bin/rackup")
    expect(out).to eq("1.0.0")
  end

  it "uses the default ruby install name when shebang is not specified" do
    carat! "binstubs rack"
    expect(File.open("bin/rackup").gets).to eq("#!/usr/bin/env #{RbConfig::CONFIG["ruby_install_name"]}\n")
  end

  it "allows the name of the shebang executable to be specified" do
    carat! "binstubs rack", :shebang => "ruby-foo"
    expect(File.open("bin/rackup").gets).to eq("#!/usr/bin/env ruby-foo\n")
  end

  it "runs the carated command when out of the carat" do
    carat! "binstubs rack"

    build_gem "rack", "2.0", :to_system => true do |s|
      s.executables = "rackup"
    end

    Dir.chdir(tmp) do
      gembin "rackup"
      expect(out).to eq("1.0.0")
    end
  end

  it "works with gems in path" do
    build_lib "rack", :path => lib_path("rack") do |s|
      s.executables = "rackup"
    end

    gemfile <<-G
      gem "rack", :path => "#{lib_path("rack")}"
    G

    carat! "binstubs rack"

    build_gem "rack", "2.0", :to_system => true do |s|
      s.executables = "rackup"
    end

    gembin "rackup"
    expect(out).to eq("1.0")
  end

  it "creates a carat binstub" do
    build_gem "carat", Carat::VERSION, :to_system => true do |s|
      s.executables = "carat"
    end

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "carat"
    G

    carat! "binstubs carat"

    expect(carated_app("bin/carat")).to exist
  end

  it "does not generate bin stubs if the option was not specified" do
    carat! "install"

    expect(carated_app("bin/rackup")).not_to exist
  end

  it "allows you to stop installing binstubs", :carat => "< 2" do
    carat! "install --binstubs bin/"
    carated_app("bin/rackup").rmtree
    carat! "install --binstubs \"\""

    expect(carated_app("bin/rackup")).not_to exist

    carat! "config bin"
    expect(out).to include("You have not configured a value for `bin`")
  end

  it "remembers that the option was specified", :carat => "< 2" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "activesupport"
    G

    carat! :install, forgotten_command_line_options([:binstubs, :bin] => "bin")

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "activesupport"
      gem "rack"
    G

    carat "install"

    expect(carated_app("bin/rackup")).to exist
  end

  it "rewrites bins on --binstubs (to maintain backwards compatibility)", :carat => "< 2" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    carat! :install, forgotten_command_line_options([:binstubs, :bin] => "bin")

    File.open(carated_app("bin/rackup"), "wb") do |file|
      file.print "OMG"
    end

    carat "install"

    expect(carated_app("bin/rackup").read).to_not eq("OMG")
  end

  it "rewrites bins on binstubs (to maintain backwards compatibility)" do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    create_file("bin/rackup", "OMG")

    carat! "binstubs rack"

    expect(carated_app("bin/rackup").read).to_not eq("OMG")
  end
end
