# frozen_string_literal: true

RSpec.describe "carat version" do
  context "with -v" do
    it "outputs the version", :carat => "< 2" do
      carat! "-v"
      expect(out).to eq("Carat version #{Carat::VERSION}")
    end

    it "outputs the version", :carat => "2" do
      carat! "-v"
      expect(out).to eq(Carat::VERSION)
    end
  end

  context "with --version" do
    it "outputs the version", :carat => "< 2" do
      carat! "--version"
      expect(out).to eq("Carat version #{Carat::VERSION}")
    end

    it "outputs the version", :carat => "2" do
      carat! "--version"
      expect(out).to eq(Carat::VERSION)
    end
  end

  context "with version" do
    it "outputs the version with build metadata", :carat => "< 2" do
      carat! "version"
      expect(out).to match(/\ACarat version #{Regexp.escape(Carat::VERSION)} \(\d{4}-\d{2}-\d{2} commit [a-fA-F0-9]{7,}\)\z/)
    end

    it "outputs the version with build metadata", :carat => "2" do
      carat! "version"
      expect(out).to match(/\A#{Regexp.escape(Carat::VERSION)} \(\d{4}-\d{2}-\d{2} commit [a-fA-F0-9]{7,}\)\z/)
    end
  end
end
