# frozen_string_literal: true

module RuboCop
  module Cop
    module Naming
      # Makes sure that all variables use the configured style,
      # snake_case or camelCase, for their names.
      #
      # @example EnforcedStyle: snake_case (default)
      #   # bad
      #   fooBar = 1
      #
      #   # good
      #   foo_bar = 1
      #
      # @example EnforcedStyle: camelCase
      #   # bad
      #   foo_bar = 1
      #
      #   # good
      #   fooBar = 1
      #
      # @example AllowedIdentifiers: ['fooBar']
      #   # good (with EnforcedStyle: snake_case)
      #   fooBar = 1
      #
      # @example AllowedPatterns: ['_v\d+\z']
      #   # good (with EnforcedStyle: camelCase)
      #   :release_v1
      #
      class VariableName < Base
        include AllowedIdentifiers
        include ConfigurableNaming
        include AllowedPattern

        MSG = 'Use %<style>s for variable names.'
        MSG_FORBIDDEN = '`%<identifier>s` is forbidden, use another name instead.'

        def valid_name?(node, name, given_style = style)
          super || matches_allowed_pattern?(name)
        end

        def on_lvasgn(node)
          return unless (name = node.name)
          return if allowed_identifier?(name)

          if forbidden_name?(name)
            register_forbidden_name(node)
          else
            check_name(node, name, node.loc.name)
          end
        end
        alias on_ivasgn    on_lvasgn
        alias on_cvasgn    on_lvasgn
        alias on_arg       on_lvasgn
        alias on_optarg    on_lvasgn
        alias on_restarg   on_lvasgn
        alias on_kwoptarg  on_lvasgn
        alias on_kwarg     on_lvasgn
        alias on_kwrestarg on_lvasgn
        alias on_blockarg  on_lvasgn
        alias on_lvar      on_lvasgn

        # Only forbidden names are checked for global variable assignment
        def on_gvasgn(node)
          return unless (name = node.name)
          return unless forbidden_name?(name)

          register_forbidden_name(node)
        end

        private

        def message(style)
          format(MSG, style: style)
        end

        def forbidden_names
          cop_config.fetch('ForbiddenNames', [])
        end

        def forbidden_name?(name)
          !forbidden_names.empty? && forbidden_names.include?(name.to_s.delete(SIGILS))
        end

        def register_forbidden_name(node)
          message = format(MSG_FORBIDDEN, identifier: node.name)
          add_offense(node.loc.name, message: message)
        end
      end
    end
  end
end
