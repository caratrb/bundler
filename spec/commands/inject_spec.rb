# frozen_string_literal: true

RSpec.describe "carat inject", :carat => "< 2" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G
  end

  context "without a lockfile" do
    it "locks with the injected gems" do
      expect(carated_app("Gemfile.lock")).not_to exist
      carat "inject 'rack-obama' '> 0'"
      expect(carated_app("Gemfile.lock").read).to match(/rack-obama/)
    end
  end

  context "with a lockfile" do
    before do
      carat "install"
    end

    it "adds the injected gems to the Gemfile" do
      expect(carated_app("Gemfile").read).not_to match(/rack-obama/)
      carat "inject 'rack-obama' '> 0'"
      expect(carated_app("Gemfile").read).to match(/rack-obama/)
    end

    it "locks with the injected gems" do
      expect(carated_app("Gemfile.lock").read).not_to match(/rack-obama/)
      carat "inject 'rack-obama' '> 0'"
      expect(carated_app("Gemfile.lock").read).to match(/rack-obama/)
    end
  end

  context "with injected gems already in the Gemfile" do
    it "doesn't add existing gems" do
      carat "inject 'rack' '> 0'"
      expect(out).to match(/cannot specify the same gem twice/i)
    end
  end

  context "incorrect arguments" do
    it "fails when more than 2 arguments are passed" do
      carat "inject gem_name 1 v"
      expect(out).to eq(<<-E.strip)
ERROR: "carat inject" was called with arguments ["gem_name", "1", "v"]
Usage: "carat inject GEM VERSION"
      E
    end
  end

  context "with source option" do
    it "add gem with source option in gemfile" do
      carat "inject 'foo' '>0' --source file://#{gem_repo1}"
      gemfile = carated_app("Gemfile").read
      str = "gem \"foo\", \"> 0\", :source => \"file://#{gem_repo1}\""
      expect(gemfile).to include str
    end
  end

  context "with group option" do
    it "add gem with group option in gemfile" do
      carat "inject 'rack-obama' '>0' --group=development"
      gemfile = carated_app("Gemfile").read
      str = "gem \"rack-obama\", \"> 0\", :group => [:development]"
      expect(gemfile).to include str
    end

    it "add gem with multiple groups in gemfile" do
      carat "inject 'rack-obama' '>0' --group=development,test"
      gemfile = carated_app("Gemfile").read
      str = "gem \"rack-obama\", \"> 0\", :groups => [:development, :test]"
      expect(gemfile).to include str
    end
  end

  context "when frozen" do
    before do
      carat "install"
      if Carat.feature_flag.carat_2_mode?
        carat! "config --local deployment true"
      else
        carat! "config --local frozen true"
      end
    end

    it "injects anyway" do
      carat "inject 'rack-obama' '> 0'"
      expect(carated_app("Gemfile").read).to match(/rack-obama/)
    end

    it "locks with the injected gems" do
      expect(carated_app("Gemfile.lock").read).not_to match(/rack-obama/)
      carat "inject 'rack-obama' '> 0'"
      expect(carated_app("Gemfile.lock").read).to match(/rack-obama/)
    end

    it "restores frozen afterwards" do
      carat "inject 'rack-obama' '> 0'"
      config = YAML.load(carated_app(".carat/config").read)
      expect(config["CARAT_DEPLOYMENT"] || config["CARAT_FROZEN"]).to eq("true")
    end

    it "doesn't allow Gemfile changes" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack-obama"
      G
      carat "inject 'rack' '> 0'"
      expect(out).to match(/trying to install in deployment mode after changing/)

      expect(carated_app("Gemfile.lock").read).not_to match(/rack-obama/)
    end
  end
end
