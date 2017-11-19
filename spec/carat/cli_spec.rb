require 'spec_helper'
require 'carat/cli'

describe "carat executable" do
  let(:source_uri) { "http://localgemserver.test" }

  it "returns non-zero exit status when passed unrecognized options" do
    carat '--invalid_argument'
    expect(exitstatus).to_not be_zero if exitstatus
  end

  it "returns non-zero exit status when passed unrecognized task" do
    carat 'unrecognized-tast'
    expect(exitstatus).to_not be_zero if exitstatus
  end

  it "looks for a binary and executes it if it's named carat-<task>" do
    File.open(tmp('carat-testtasks'), 'w', 0755) do |f|
      f.puts "#!/usr/bin/env ruby\nputs 'Hello, world'\n"
    end

    with_path_as(tmp) do
      carat 'testtasks'
    end

    expect(exitstatus).to be_zero if exitstatus
    expect(out).to eq('Hello, world')
  end
end
