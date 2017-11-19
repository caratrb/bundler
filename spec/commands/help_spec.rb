require "spec_helper"

describe "carat help" do
  # Rubygems 1.4+ no longer load gem plugins so this test is no longer needed
  rubygems_under_14 = Gem::Requirement.new("< 1.4").satisfied_by?(Gem::Version.new(Gem::VERSION))
  it "complains if older versions of carat are installed", :if => rubygems_under_14 do
    system_gems "carat-0.8.1"

    carat "help", :expect_err => true
    expect(err).to include("older than 0.9")
    expect(err).to include("running `gem cleanup carat`.")
  end

  it "uses mann when available" do
    fake_man!

    carat "help gemfile"
    expect(out).to eq(%|["#{root}/lib/carat/man/gemfile.5"]|)
  end

  it "prefixes carat commands with carat- when finding the groff files" do
    fake_man!

    carat "help install"
    expect(out).to eq(%|["#{root}/lib/carat/man/carat-install"]|)
  end

  it "simply outputs the txt file when there is no man on the path" do
    kill_path!

    carat "help install", :expect_err => true
    expect(out).to match(/CARAT-INSTALL/)
  end

  it "still outputs the old help for commands that do not have man pages yet" do
    carat "help check"
    expect(out).to include("Check searches the local machine")
  end
end
