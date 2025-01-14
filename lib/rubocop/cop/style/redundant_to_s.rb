# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # Checks for redundant uses of `to_s`.
      #
      # `to_s` is redundant when called on a string literal, interpolated string, `String.new`,
      # heredoc, or when chained with itself.
      #
      # @safety
      #   Autocorrect is unsafe because the cop assumes that `to_s` called on an object returns
      #   a string, which would make a subsequent `to_s` call redundant. However, if `to_s` is
      #   overridden on the receiver or on `String`, this may not be the case.
      #
      # @example
      #   # bad
      #   "text".to_s
      #
      #   # good
      #   "text"
      #
      #   # bad
      #   "#{foo}".to_s
      #
      #   # good
      #   "#{foo}"
      #
      #   # bad
      #   String.new('text').to_s
      #
      #   # good
      #   String.new('text')
      #
      #   # bad
      #   <<~STR.to_s
      #     text
      #   STR
      #
      #   # good
      #   <<~STR
      #     text
      #   STR
      #
      #   # bad
      #   foo.to_s.to_s
      #
      #   # good
      #   foo.to_s
      #
      class RedundantToS < Base
        extend AutoCorrector

        MSG = 'Redundant `to_s` detected.'

        RESTRICT_ON_SEND = %i[to_s].freeze

        # @!method string_new?(node)
        def_node_matcher :string_new?, <<~PATTERN
          (send (const {cbase nil?} :String) :new ...)
        PATTERN

        # @!method to_s_call?(node)
        def_node_matcher :to_s_call?, <<~PATTERN
          (call _ :to_s ...)
        PATTERN

        def on_send(node)
          receiver = find_receiver(node)
          return unless string_receiver?(receiver) || to_s_call?(receiver)

          add_offense(node.loc.selector) do |corrector|
            corrector.remove(node.loc.dot.join(node.loc.selector))
          end
        end
        alias on_csend on_send

        private

        def find_receiver(node)
          receiver = node.receiver
          return unless receiver

          while receiver.begin_type?
            break unless receiver.children.one?

            receiver = receiver.children.first
          end

          receiver
        end

        def string_receiver?(receiver)
          return false unless receiver

          receiver.type?(:str, :dstr) || string_new?(receiver)
        end
      end
    end
  end
end
