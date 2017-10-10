# frozen_string_literal: true

RSpec.describe "carat install" do
  context "git sources" do
    it "displays the revision hash of the gem repository", :carat => "< 2" do
      build_git "foo", "1.0", :path => lib_path("foo")

      install_gemfile <<-G
        gem "foo", :git => "#{lib_path("foo")}"
      G

      carat! :install
      expect(out).to include("Using foo 1.0 from #{lib_path("foo")} (at master@#{revision_for(lib_path("foo"))[0..6]})")
      expect(the_carat).to include_gems "foo 1.0", :source => "git@#{lib_path("foo")}"
    end

    it "displays the ref of the gem repository when using branch~num as a ref", :carat => "< 2" do
      build_git "foo", "1.0", :path => lib_path("foo")
      rev = revision_for(lib_path("foo"))[0..6]
      update_git "foo", "2.0", :path => lib_path("foo"), :gemspec => true
      rev2 = revision_for(lib_path("foo"))[0..6]
      update_git "foo", "3.0", :path => lib_path("foo"), :gemspec => true

      install_gemfile! <<-G
        gem "foo", :git => "#{lib_path("foo")}", :ref => "master~2"
      G

      carat! :install
      expect(out).to include("Using foo 1.0 from #{lib_path("foo")} (at master~2@#{rev})")
      expect(the_carat).to include_gems "foo 1.0", :source => "git@#{lib_path("foo")}"

      update_git "foo", "4.0", :path => lib_path("foo"), :gemspec => true

      carat! :update, :all => carat_update_requires_all?
      expect(out).to include("Using foo 2.0 (was 1.0) from #{lib_path("foo")} (at master~2@#{rev2})")
      expect(the_carat).to include_gems "foo 2.0", :source => "git@#{lib_path("foo")}"
    end

    it "should allows git repos that are missing but not being installed" do
      revision = build_git("foo").ref_for("HEAD")

      gemfile <<-G
        gem "foo", :git => "file://#{lib_path("foo-1.0")}", :group => :development
      G

      lockfile <<-L
        GIT
          remote: file://#{lib_path("foo-1.0")}
          revision: #{revision}
          specs:
            foo (1.0)

        PLATFORMS
          ruby

        DEPENDENCIES
          foo!
      L

      carat! :install, forgotten_command_line_options(:path => "vendor/carat", :without => "development")

      expect(out).to include("Carat complete!")
    end
  end
end
