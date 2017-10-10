# frozen_string_literal: true

RSpec.describe "carat compatibility guard" do
  context "when the carat version is 2+" do
    before { simulate_carat_version "2.0.a" }

    context "when running on Ruby < 2.3", :ruby => "< 2.3" do
      before { simulate_rubygems_version "2.6.11" }

      it "raises a friendly error" do
        carat :version
        expect(err).to eq("Carat 2 requires Ruby 2.3 or later. Either install carat 1 or update to a supported Ruby version.")
      end
    end

    context "when running on RubyGems < 2.5", :ruby => ">= 2.5" do
      before { simulate_rubygems_version "1.3.6" }

      it "raises a friendly error" do
        carat :version
        expect(err).to eq("Carat 2 requires RubyGems 2.5 or later. Either install carat 1 or update to a supported RubyGems version.")
      end
    end
  end
end
