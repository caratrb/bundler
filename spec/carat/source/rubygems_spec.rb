# frozen_string_literal: true

RSpec.describe Carat::Source::Rubygems do
  before do
    allow(Carat).to receive(:root) { Pathname.new("root") }
  end

  describe "caches" do
    it "includes Carat.app_cache" do
      expect(subject.caches).to include(Carat.app_cache)
    end

    it "includes GEM_PATH entries" do
      Gem.path.each do |path|
        expect(subject.caches).to include(File.expand_path("#{path}/cache"))
      end
    end

    it "is an array of strings or pathnames" do
      subject.caches.each do |cache|
        expect([String, Pathname]).to include(cache.class)
      end
    end
  end

  describe "#add_remote" do
    context "when the source is an HTTP(s) URI with no host" do
      it "raises error" do
        expect { subject.add_remote("https:rubygems.org") }.to raise_error(ArgumentError)
      end
    end
  end
end
