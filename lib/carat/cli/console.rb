module Carat
  class CLI::Console
    attr_reader :options, :group
    def initialize(options, group)
      @options = options
      @group = group
    end

    def run
      group ? Carat.require(:default, *(group.split.map! {|g| g.to_sym })) : Carat.require
      ARGV.clear

      console = get_console(Carat.settings[:console] || 'irb')
      console.start
    end

    def get_console(name)
      require name
      get_constant(name)
    rescue LoadError
      Carat.ui.error "Couldn't load console #{name}"
      get_constant('irb')
    end

    def get_constant(name)
      const_name = {
        'pry'  => :Pry,
        'ripl' => :Ripl,
        'irb'  => :IRB,
      }[name]
      Object.const_get(const_name)
    rescue NameError
      Carat.ui.error "Could not find constant #{const_name}"
      exit 1
    end

  end
end
