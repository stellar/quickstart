# frozen_string_literal: true

module RuboCop
  module Cop
    module Local
      # Disallows trailing (modifier) `if`/`unless`, e.g. `do_thing if cond`.
      # Conditionals must be written as ordinary multi-line statements.
      class NoModifierConditional < RuboCop::Cop::Base
        MSG = "Do not use a trailing `if`/`unless`; write it as a multi-line statement."

        def on_if(node)
          return unless node.modifier_form?

          add_offense(node.loc.keyword)
        end
      end
    end
  end
end
