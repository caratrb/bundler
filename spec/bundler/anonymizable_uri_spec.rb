require 'spec_helper'
require 'carat/anonymizable_uri'

describe Carat::AnonymizableURI do
  def auri(uri, auth = nil)
    Carat::AnonymizableURI.new(uri, auth)
  end

  describe "#without_credentials" do
    context "when the original URI has no credentials" do
      let(:original_uri) { URI('https://rubygems.org') }

      it "returns the original URI" do
        expect(auri(original_uri).without_credentials).to eq(original_uri)
      end

      it "applies given credentials" do
        with_auth = original_uri.dup
        with_auth.userinfo = "user:pass"
        expect(auri(original_uri, "user:pass").original_uri).to eq(with_auth)
      end
    end

    context "when the original URI has a username and password" do
      let(:original_uri) { URI("https://username:password@gems.example.com") }

      it "returns the URI without username and password" do
        expect(auri(original_uri).without_credentials).to eq(URI("https://gems.example.com"))
      end

      it "does not apply given credentials" do
        expect(auri(original_uri, "other:stuff").original_uri).to eq(original_uri)
      end
    end

    context "when the original URI has only a username" do
      let(:original_uri) { URI("https://SeCrEt-ToKeN@gem.fury.io/me/") }

      it "returns the URI without username and password" do
        expect(auri(original_uri).without_credentials).to eq(URI("https://gem.fury.io/me/"))
      end
    end
  end
end
