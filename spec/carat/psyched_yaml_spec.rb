require 'spec_helper'
require 'carat/psyched_yaml'

describe Carat::YamlSyntaxError do
  it "is raised on YAML parse errors" do
    expect{ YAML.parse "{foo" }.to raise_error(Carat::YamlSyntaxError)
  end
end
