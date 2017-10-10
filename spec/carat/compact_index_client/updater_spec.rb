# frozen_string_literal: true

require "net/http"
require "carat/compact_index_client"
require "carat/compact_index_client/updater"

RSpec.describe Carat::CompactIndexClient::Updater do
  subject(:updater) { described_class.new(fetcher) }

  let(:fetcher) { double(:fetcher) }

  context "when the ETag header is missing" do
    # Regression test for https://github.com/caratrb/carat/issues/5463

    let(:response) { double(:response, :body => "") }
    let(:local_path) { Pathname("/tmp/localpath") }
    let(:remote_path) { double(:remote_path) }

    it "MisMatchedChecksumError is raised" do
      # Twice: #update retries on failure
      expect(response).to receive(:[]).with("Content-Encoding").twice { "" }
      expect(response).to receive(:[]).with("ETag").twice { nil }
      expect(fetcher).to receive(:call).twice { response }

      expect do
        updater.update(local_path, remote_path)
      end.to raise_error(Carat::CompactIndexClient::Updater::MisMatchedChecksumError)
    end
  end

  context "when carat doesn't have permissions on Dir.tmpdir" do
    let(:response) { double(:response, :body => "") }
    let(:local_path) { Pathname("/tmp/localpath") }
    let(:remote_path) { double(:remote_path) }

    it "Errno::EACCES is raised" do
      allow(Dir).to receive(:mktmpdir) { raise Errno::EACCES }

      expect do
        updater.update(local_path, remote_path)
      end.to raise_error(Carat::PermissionError)
    end
  end
end
