# frozen_string_literal: true

require "carat/psyched_yaml"

RSpec.describe "Carat::YamlLibrarySyntaxError" do
  it "is raised on YAML parse errors" do
    expect { YAML.parse "{foo" }.to raise_error(Carat::YamlLibrarySyntaxError)
  end
end
