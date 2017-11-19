require "spec_helper"

describe "carat install for the first time with v1.0" do
  before :each do
    in_app_root

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  it "removes lockfiles in 0.9 YAML format" do
    File.open("Gemfile.lock", "w"){|f| YAML.dump({}, f) }
    carat :install
    expect(File.read("Gemfile.lock")).not_to match(/^---/)
  end

  it "removes env.rb if it exists" do
    bundled_app.join(".carat").mkdir
    bundled_app.join(".carat/environment.rb").open("w"){|f| f.write("raise 'nooo'") }
    carat :install
    expect(bundled_app.join(".carat/environment.rb")).not_to exist
  end

end
