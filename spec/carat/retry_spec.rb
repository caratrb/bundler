require 'spec_helper'

describe Carat::Retry do
  it "return successful result if no errors" do
    attempts = 0
    result = Carat::Retry.new(nil, nil, 3).attempt do
      attempts += 1
      :success
    end
    expect(result).to eq(:success)
    expect(attempts).to eq(1)
  end

  it "defaults to retrying twice" do
    attempts = 0
    expect {
      Carat::Retry.new(nil).attempt do
        attempts += 1
        raise "nope"
      end
    }.to raise_error("nope")
    expect(attempts).to eq(3)
  end

  it "returns the first valid result" do
    jobs = [Proc.new{ raise "foo" }, Proc.new{ :bar }, Proc.new{ raise "foo" }]
    attempts = 0
    result = Carat::Retry.new(nil, nil, 3).attempt do
      attempts += 1
      jobs.shift.call
    end
    expect(result).to eq(:bar)
    expect(attempts).to eq(2)
  end

  it "raises the last error" do
    errors = [StandardError, StandardError, StandardError, Carat::GemfileNotFound]
    attempts = 0
    expect {
      Carat::Retry.new(nil, nil, 3).attempt do
        attempts += 1
        raise errors.shift
      end
    }.to raise_error(Carat::GemfileNotFound)
    expect(attempts).to eq(4)
  end

  it "raises exceptions" do
    error = Carat::GemfileNotFound
    attempts = 0
    expect {
      Carat::Retry.new(nil, error).attempt do
        attempts += 1
        raise error
      end
    }.to raise_error(error)
    expect(attempts).to eq(1)
  end
end
