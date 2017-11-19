require "spec_helper"

describe "carat console" do
  before :each do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
      gem "activesupport", :group => :test
      gem "rack_middleware", :group => :development
    G
  end

  it "starts IRB with the default group loaded" do
    carat "console" do |input|
      input.puts("puts RACK")
      input.puts("exit")
    end
    expect(out).to include("0.9.1")
  end

  it "starts another REPL if configured as such" do
    carat "config console pry"

    carat "console" do |input|
      input.puts("__callee__")
      input.puts("exit")
    end
    expect(out).to include("pry")
  end

  it "falls back to IRB if the other REPL isn't available" do
    carat "config console pry"
    # make sure pry isn't there

    carat "console" do |input|
      input.puts("__callee__")
      input.puts("exit")
    end
    expect(out).to include("IRB")
  end

  it "doesn't load any other groups" do
    carat "console" do |input|
      input.puts("puts ACTIVESUPPORT")
      input.puts("exit")
    end
    expect(out).to include("NameError")
  end

  describe "when given a group" do
    it "loads the given group" do
      carat "console test" do |input|
        input.puts("puts ACTIVESUPPORT")
        input.puts("exit")
      end
      expect(out).to include("2.3.5")
    end

    it "loads the default group" do
      carat "console test" do |input|
        input.puts("puts RACK")
        input.puts("exit")
      end
      expect(out).to include("0.9.1")
    end

    it "doesn't load other groups" do
      carat "console test" do |input|
        input.puts("puts RACK_MIDDLEWARE")
        input.puts("exit")
      end
      expect(out).to include("NameError")
    end
  end

  it "performs an automatic carat install" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
      gem "activesupport", :group => :test
      gem "rack_middleware", :group => :development
      gem "foo"
    G

    carat "config auto_install 1"
    carat :console do |input|
      input.puts("puts 'hello'")
      input.puts("exit")
    end
    expect(out).to include("Installing foo 1.0")
    expect(out).to include("hello")
    should_be_installed "foo 1.0"
  end
end
