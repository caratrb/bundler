# frozen_string_literal: true

RSpec.describe "Carat.load" do
  describe "with a gemfile" do
    before(:each) do
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    it "provides a list of the env dependencies" do
      expect(Carat.load.dependencies).to have_dep("rack", ">= 0")
    end

    it "provides a list of the resolved gems" do
      expect(Carat.load.gems).to have_gem("rack-1.0.0", "carat-#{Carat::VERSION}")
    end

    it "ignores blank CARAT_GEMFILEs" do
      expect do
        ENV["CARAT_GEMFILE"] = ""
        Carat.load
      end.not_to raise_error
    end
  end

  describe "with a gems.rb file" do
    before(:each) do
      create_file "gems.rb", <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      carat! :install
    end

    it "provides a list of the env dependencies" do
      expect(Carat.load.dependencies).to have_dep("rack", ">= 0")
    end

    it "provides a list of the resolved gems" do
      expect(Carat.load.gems).to have_gem("rack-1.0.0", "carat-#{Carat::VERSION}")
    end
  end

  describe "without a gemfile" do
    it "raises an exception if the default gemfile is not found" do
      expect do
        Carat.load
      end.to raise_error(Carat::GemfileNotFound, /could not locate gemfile/i)
    end

    it "raises an exception if a specified gemfile is not found" do
      expect do
        ENV["CARAT_GEMFILE"] = "omg.rb"
        Carat.load
      end.to raise_error(Carat::GemfileNotFound, /omg\.rb/)
    end

    it "does not find a Gemfile above the testing directory" do
      carat_gemfile = tmp.join("../Gemfile")
      unless File.exist?(carat_gemfile)
        FileUtils.touch(carat_gemfile)
        @remove_carat_gemfile = true
      end
      begin
        expect { Carat.load }.to raise_error(Carat::GemfileNotFound)
      ensure
        carat_gemfile.rmtree if @remove_carat_gemfile
      end
    end
  end

  describe "when called twice" do
    it "doesn't try to load the runtime twice" do
      install_gemfile! <<-G
        source "file:#{gem_repo1}"
        gem "rack"
        gem "activesupport", :group => :test
      G

      ruby! <<-RUBY
        require "carat"
        Carat.setup :default
        Carat.require :default
        puts RACK
        begin
          require "activesupport"
        rescue LoadError
          puts "no activesupport"
        end
      RUBY

      expect(out.split("\n")).to eq(["1.0.0", "no activesupport"])
    end
  end

  describe "not hurting brittle rubygems" do
    it "does not inject #source into the generated YAML of the gem specs" do
      install_gemfile! <<-G
        source "file:#{gem_repo1}"
        gem "activerecord"
      G

      Carat.load.specs.each do |spec|
        expect(spec.to_yaml).not_to match(/^\s+source:/)
        expect(spec.to_yaml).not_to match(/^\s+groups:/)
      end
    end
  end
end
