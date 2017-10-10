# frozen_string_literal: true

module Carat::Molinillo
  # @!visibility private
  module Delegates
    # Delegates all {Carat::Molinillo::ResolutionState} methods to a `#state` property.
    module ResolutionState
      # (see Carat::Molinillo::ResolutionState#name)
      def name
        current_state = state || Carat::Molinillo::ResolutionState.empty
        current_state.name
      end

      # (see Carat::Molinillo::ResolutionState#requirements)
      def requirements
        current_state = state || Carat::Molinillo::ResolutionState.empty
        current_state.requirements
      end

      # (see Carat::Molinillo::ResolutionState#activated)
      def activated
        current_state = state || Carat::Molinillo::ResolutionState.empty
        current_state.activated
      end

      # (see Carat::Molinillo::ResolutionState#requirement)
      def requirement
        current_state = state || Carat::Molinillo::ResolutionState.empty
        current_state.requirement
      end

      # (see Carat::Molinillo::ResolutionState#possibilities)
      def possibilities
        current_state = state || Carat::Molinillo::ResolutionState.empty
        current_state.possibilities
      end

      # (see Carat::Molinillo::ResolutionState#depth)
      def depth
        current_state = state || Carat::Molinillo::ResolutionState.empty
        current_state.depth
      end

      # (see Carat::Molinillo::ResolutionState#conflicts)
      def conflicts
        current_state = state || Carat::Molinillo::ResolutionState.empty
        current_state.conflicts
      end

      # (see Carat::Molinillo::ResolutionState#unused_unwind_options)
      def unused_unwind_options
        current_state = state || Carat::Molinillo::ResolutionState.empty
        current_state.unused_unwind_options
      end
    end
  end
end
