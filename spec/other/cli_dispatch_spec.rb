require "spec_helper"

describe "carat command names" do
  it "work when given fully" do
    carat "install"
    expect(err).to eq("")
    expect(out).not_to match(/Ambiguous command/)
  end

  it "work when not ambiguous" do
    carat "ins"
    expect(err).to eq("")
    expect(out).not_to match(/Ambiguous command/)
  end

  it "print a friendly error when ambiguous" do
    carat "i"
    expect(err).to eq("")
    expect(out).to match(/Ambiguous command/)
  end
end
