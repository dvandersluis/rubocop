# frozen_string_literal: true

module RuboCop
  module Cop
    # This module encapsulates the logic for autocorrect behavior for a cop.
    module AutocorrectLogic
      def autocorrect?
        autocorrect_requested? && correctable? && autocorrect_enabled?
      end

      def autocorrect_with_disable_uncorrectable?
        autocorrect_requested? && disable_uncorrectable? && autocorrect_enabled?
      end

      def autocorrect_requested?
        @options.fetch(:autocorrect, false)
      end

      def correctable?
        self.class.support_autocorrect? #|| disable_uncorrectable?
      end

      def disable_uncorrectable?
        @options[:disable_uncorrectable] == true
      end

      def safe_autocorrect?
        cop_config.fetch('Safe', true) && cop_config.fetch('SafeAutoCorrect', true)
      end

      def autocorrect_enabled?
        # allow turning off autocorrect on a cop by cop basis
        return true unless cop_config

        # `false` is the same as `disabled` for backward compatibility.
        return false if ['disabled', false].include?(cop_config['AutoCorrect'])

        # When LSP is enabled, it is considered as editing source code,
        # and autocorrection with `AutoCorrect: contextual` will not be performed.
        return false if contextual_autocorrect? && LSP.enabled?

        # :safe_autocorrect is a derived option based on several command-line
        # arguments - see RuboCop::Options#add_autocorrection_options
        return safe_autocorrect? if @options.fetch(:safe_autocorrect, false)

        true
      end

      private

      def max_line_length
        config.for_cop('Layout/LineLength')['Max'] || 120
      end
    end
  end
end
