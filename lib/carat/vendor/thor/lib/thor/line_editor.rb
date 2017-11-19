require "carat/vendor/thor/lib/thor/line_editor/basic"
require "carat/vendor/thor/lib/thor/line_editor/readline"

class Carat::Thor
  module LineEditor
    def self.readline(prompt, options = {})
      best_available.new(prompt, options).readline
    end

    def self.best_available
      [
        Carat::Thor::LineEditor::Readline,
        Carat::Thor::LineEditor::Basic
      ].detect(&:available?)
    end
  end
end
