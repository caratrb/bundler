require "spec_helper"

describe "carat open" do
  before :each do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
    G
  end

  it "opens the gem with CARAT_EDITOR as highest priority" do
    carat "open rails", :env => {"EDITOR" => "echo editor", "VISUAL" => "echo visual", "CARAT_EDITOR" => "echo carat_editor"}
    expect(out).to eq("carat_editor #{default_bundle_path('gems', 'rails-2.3.2')}")
  end

  it "opens the gem with VISUAL as 2nd highest priority" do
    carat "open rails", :env => {"EDITOR" => "echo editor", "VISUAL" => "echo visual", "CARAT_EDITOR" => ""}
    expect(out).to eq("visual #{default_bundle_path('gems', 'rails-2.3.2')}")
  end

  it "opens the gem with EDITOR as 3rd highest priority" do
    carat "open rails", :env => {"EDITOR" => "echo editor", "VISUAL" => "", "CARAT_EDITOR" => ""}
    expect(out).to eq("editor #{default_bundle_path('gems', 'rails-2.3.2')}")
  end

  it "complains if no EDITOR is set" do
    carat "open rails", :env => {"EDITOR" => "", "VISUAL" => "", "CARAT_EDITOR" => ""}
    expect(out).to eq("To open a bundled gem, set $EDITOR or $CARAT_EDITOR")
  end

  it "complains if gem not in bundle" do
    carat "open missing", :env => {"EDITOR" => "echo editor", "VISUAL" => "", "CARAT_EDITOR" => ""}
    expect(out).to match(/could not find gem 'missing'/i)
  end

  it "does not blow up if the gem to open does not have a Gemfile" do
    git = build_git "foo"
    ref = git.ref_for("master", 11)

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem 'foo', :git => "#{lib_path("foo-1.0")}"
    G

    carat "open foo", :env => {"EDITOR" => "echo editor", "VISUAL" => "", "CARAT_EDITOR" => ""}
    expect(out).to match("editor #{default_bundle_path.join("carat/gems/foo-1.0-#{ref}")}")
  end

  it "suggests alternatives for similar-sounding gems" do
    carat "open Rails", :env => {"EDITOR" => "echo editor", "VISUAL" => "", "CARAT_EDITOR" => ""}
    expect(out).to match(/did you mean rails\?/i)
  end

  it "opens the gem with short words" do
    carat "open rec" , :env => {"EDITOR" => "echo editor", "VISUAL" => "echo visual", "CARAT_EDITOR" => "echo carat_editor"}

    expect(out).to eq("carat_editor #{default_bundle_path('gems', 'activerecord-2.3.2')}")
  end

  it "select the gem from many match gems" do
    env = {"EDITOR" => "echo editor", "VISUAL" => "echo visual", "CARAT_EDITOR" => "echo carat_editor"}
    carat "open active" , :env => env do |input|
      input.puts '2'
    end

    expect(out).to match(/carat_editor #{default_bundle_path('gems', 'activerecord-2.3.2')}\z/)
  end

  it "performs an automatic carat install" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
      gem "foo"
    G

    carat "config auto_install 1"
    carat "open rails", :env => {"EDITOR" => "echo editor", "VISUAL" => "", "CARAT_EDITOR" => ""}
    expect(out).to include("Installing foo 1.0")
  end
end
