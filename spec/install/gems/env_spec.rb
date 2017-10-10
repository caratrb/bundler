# frozen_string_literal: true

RSpec.describe "carat install with ENV conditionals" do
  describe "when just setting an ENV key as a string" do
    before :each do
      gemfile <<-G
        source "file://#{gem_repo1}"

        env "CARATR_TEST" do
          gem "rack"
        end
      G
    end

    it "excludes the gems when the ENV variable is not set" do
      carat :install
      expect(the_carat).not_to include_gems "rack"
    end

    it "includes the gems when the ENV variable is set" do
      ENV["CARATR_TEST"] = "1"
      carat :install
      expect(the_carat).to include_gems "rack 1.0"
    end
  end

  describe "when just setting an ENV key as a symbol" do
    before :each do
      gemfile <<-G
        source "file://#{gem_repo1}"

        env :CARATR_TEST do
          gem "rack"
        end
      G
    end

    it "excludes the gems when the ENV variable is not set" do
      carat :install
      expect(the_carat).not_to include_gems "rack"
    end

    it "includes the gems when the ENV variable is set" do
      ENV["CARATR_TEST"] = "1"
      carat :install
      expect(the_carat).to include_gems "rack 1.0"
    end
  end

  describe "when setting a string to match the env" do
    before :each do
      gemfile <<-G
        source "file://#{gem_repo1}"

        env "CARATR_TEST" => "foo" do
          gem "rack"
        end
      G
    end

    it "excludes the gems when the ENV variable is not set" do
      carat :install
      expect(the_carat).not_to include_gems "rack"
    end

    it "excludes the gems when the ENV variable is set but does not match the condition" do
      ENV["CARATR_TEST"] = "1"
      carat :install
      expect(the_carat).not_to include_gems "rack"
    end

    it "includes the gems when the ENV variable is set and matches the condition" do
      ENV["CARATR_TEST"] = "foo"
      carat :install
      expect(the_carat).to include_gems "rack 1.0"
    end
  end

  describe "when setting a regex to match the env" do
    before :each do
      gemfile <<-G
        source "file://#{gem_repo1}"

        env "CARATR_TEST" => /foo/ do
          gem "rack"
        end
      G
    end

    it "excludes the gems when the ENV variable is not set" do
      carat :install
      expect(the_carat).not_to include_gems "rack"
    end

    it "excludes the gems when the ENV variable is set but does not match the condition" do
      ENV["CARATR_TEST"] = "fo"
      carat :install
      expect(the_carat).not_to include_gems "rack"
    end

    it "includes the gems when the ENV variable is set and matches the condition" do
      ENV["CARATR_TEST"] = "foobar"
      carat :install
      expect(the_carat).to include_gems "rack 1.0"
    end
  end
end
