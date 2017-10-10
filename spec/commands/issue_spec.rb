# frozen_string_literal: true

RSpec.describe "carat issue" do
  it "exits with a message" do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rails"
    G

    carat "issue"
    expect(out).to include "Did you find an issue with Carat?"
    expect(out).to include "## Environment"
    expect(out).to include "## Gemfile"
    expect(out).to include "## Carat Doctor"
  end
end
