# frozen_string_literal: true

RSpec.describe Carat::StubSpecification do
  let(:gemspec) do
    Gem::Specification.new do |s|
      s.name = "gemname"
      s.version = "1.0.0"
      s.loaded_from = __FILE__
    end
  end

  let(:with_carat_stub_spec) do
    described_class.from_stub(gemspec)
  end

  if Carat.rubygems.provides?(">= 2.1")
    describe "#from_stub" do
      it "returns the same stub if already a Carat::StubSpecification" do
        stub = described_class.from_stub(with_carat_stub_spec)
        expect(stub).to be(with_carat_stub_spec)
      end
    end
  end
end
