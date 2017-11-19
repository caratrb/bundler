require "spec_helper"

describe "carat licenses" do
  before :each do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
      gem "with_license"
    G
  end

  it "prints license information for all gems in the bundle" do
    carat "licenses"

    expect(out).to include("actionpack: Unknown")
    expect(out).to include("with_license: MIT")
  end

  it "performs an automatic carat install" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
      gem "with_license"
      gem "foo"
    G

    carat "config auto_install 1"
    carat :licenses
    expect(out).to include("Installing foo 1.0")
  end
end
