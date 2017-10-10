# frozen_string_literal: true

RSpec.describe "process lock spec" do
  describe "when an install operation is already holding a process lock" do
    before { FileUtils.mkdir_p(default_carat_path) }

    it "will not run a second concurrent carat install until the lock is released" do
      thread = Thread.new do
        Carat::ProcessLock.lock(default_carat_path) do
          sleep 1 # ignore quality_spec
          expect(the_carat).not_to include_gems "rack 1.0"
        end
      end

      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      thread.join
      expect(the_carat).to include_gems "rack 1.0"
    end
  end
end
