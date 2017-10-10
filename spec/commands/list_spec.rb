# frozen_string_literal: true

RSpec.describe "carat list", :carat => "2" do
  before do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  context "with name-only option" do
    it "prints only the name of the gems in the carat" do
      carat "list --name-only"
      expect(out).to eq "rack"
    end
  end

  context "when no gems are in the gemfile" do
    before do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
      G
    end

    it "prints message saying no gems are in the carat" do
      carat "list"
      expect(out).to include("No gems in the Gemfile")
    end
  end

  it "lists gems installed in the carat" do
    carat "list"
    expect(out).to include("  * rack (1.0.0)")
  end

  it "aliases the ls command to list" do
    carat "ls"
    expect(out).to include("Gems included by the carat")
  end
end
