# frozen_string_literal: true

RSpec.describe "carat command names" do
  it "work when given fully" do
    carat "install"
    expect(last_command.carat_err).to eq("Could not locate Gemfile")
    expect(last_command.stdboth).not_to include("Ambiguous command")
  end

  it "work when not ambiguous" do
    carat "ins"
    expect(last_command.carat_err).to eq("Could not locate Gemfile")
    expect(last_command.stdboth).not_to include("Ambiguous command")
  end

  it "print a friendly error when ambiguous" do
    carat "in"
    expect(last_command.carat_err).to eq("Ambiguous command in matches [info, init, inject, install]")
  end

  context "when cache_command_is_package is set" do
    before { carat! "config cache_command_is_package true" }

    it "dispatches `carat cache` to the package command" do
      carat "cache --verbose"
      expect(last_command.stdout).to start_with "Running `carat package --no-color --verbose`"
    end
  end
end
