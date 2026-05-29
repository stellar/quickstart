# frozen_string_literal: true

module RuboCop
  module Cop
    module Local
      # Disallows `unless`. Use `if` with a negated condition instead, which
      # reads more predictably for people who don't write Ruby every day.
      class NoUnless < RuboCop::Cop::Base
        MSG = "Do not use `unless`; use `if` with a negated condition."

        def on_if(node)
          return unless node.unless?

          add_offense(node.loc.keyword)
        end
      end
    end
  end
end
