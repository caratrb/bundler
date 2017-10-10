# frozen_string_literal: true

RSpec.describe "carat install" do
  %w[force redownload].each do |flag|
    describe_opts = {}
    describe_opts[:carat] = "< 2" if flag == "force"
    describe "with --#{flag}", describe_opts do
      before :each do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
        G
      end

      it "re-installs installed gems" do
        rack_lib = default_carat_path("gems/rack-1.0.0/lib/rack.rb")

        carat! :install
        rack_lib.open("w") {|f| f.write("blah blah blah") }
        carat! :install, flag => true

        expect(out).to include "Installing rack 1.0.0"
        expect(rack_lib.open(&:read)).to eq("RACK = '1.0.0'\n")
        expect(the_carat).to include_gems "rack 1.0.0"
      end

      it "works on first carat install" do
        carat! :install, flag => true

        expect(out).to include "Installing rack 1.0.0"
        expect(the_carat).to include_gems "rack 1.0.0"
      end

      context "with a git gem" do
        let!(:ref) { build_git("foo", "1.0").ref_for("HEAD", 11) }

        before do
          gemfile <<-G
            gem "foo", :git => "#{lib_path("foo-1.0")}"
          G
        end

        it "re-installs installed gems" do
          foo_lib = default_carat_path("carat/gems/foo-1.0-#{ref}/lib/foo.rb")

          carat! :install
          foo_lib.open("w") {|f| f.write("blah blah blah") }
          carat! :install, flag => true

          expect(foo_lib.open(&:read)).to eq("FOO = '1.0'\n")
          expect(the_carat).to include_gems "foo 1.0"
        end

        it "works on first carat install" do
          carat! :install, flag => true

          expect(the_carat).to include_gems "foo 1.0"
        end
      end
    end
  end
end
