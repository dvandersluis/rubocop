# frozen_string_literal: true

module RuboCop
  module Cop
    # Performs corrections to disable an offense with `rubocop:todo` directives
    # TODO: cleanup code, handle adding unnecessary disable?, determine if multiple
    # cops should be split up onto separate wrapping lines if necessary.
    class DisableUncorrectable
      include AutocorrectLogic

      def initialize(config, processed_source, cop_names)
        @processed_source = processed_source
        @cop_names = cop_names.uniq
        @config = config
      end

      attr_reader :config, :processed_source, :cop_names

      def disable_offense(offense_range)
        range = surrounding_heredoc(offense_range) ||
          surrounding_percent_array(offense_range) ||
          string_continuation(offense_range)

        if range
          disable_offense_before_and_after(range_by_lines(range))
        else
          disable_offense_with_eol_or_surround_comment(offense_range)
        end
      end

      private

      def disable_offense_with_eol_or_surround_comment(range)
        existing_comment = processed_source.comment_at_line(range.first_line)
        directive = DirectiveComment.new(existing_comment)
        # return if directive.match?([cop_name])

        eol_comment = eol_comment(directive)

        needed_line_length = (range.source_line + eol_comment).length

        if existing_comment && !directive.todo? || needed_line_length > max_line_length
          disable_offense_before_and_after(range_by_lines(range))
        else
          disable_offense_at_end_of_line(range_of_first_line(range), eol_comment)
        end
      end

      def eol_comment(directive)
        if directive.todo?
          ", #{cop_names.join(', ')}"
        else
          " # rubocop:todo #{cop_names.join(', ')}"
        end
      end

      def surrounding_heredoc(offense_range)
        # The empty offense range is an edge case that can be reached from the Lint/Syntax cop.
        return nil if offense_range.empty?

        heredoc_nodes = processed_source.ast.each_descendant.select do |node|
          node.respond_to?(:heredoc?) && node.heredoc?
        end
        heredoc_nodes.map { |node| node.source_range.join(node.loc.heredoc_end) }
                     .find { |range| range.contains?(offense_range) }
      end

      def surrounding_percent_array(offense_range)
        return nil if offense_range.empty?

        percent_array = processed_source.ast.each_descendant.select do |node|
          node.array_type? && node.percent_literal?
        end

        percent_array.map(&:source_range).find do |range|
          range_overlaps_offense?(offense_range, range)
        end
      end

      def string_continuation(offense_range)
        return nil if offense_range.empty?

        string_continuation_nodes = processed_source.ast.each_descendant.filter_map do |node|
          range_by_lines(node.source_range) if string_continuation?(node)
        end

        string_continuation_nodes.find { |range| range_overlaps_offense?(offense_range, range) }
      end

      def range_overlaps_offense?(offense_range, range)
        offense_range.begin_pos >= range.begin_pos && range.overlaps?(offense_range)
      end

      def string_continuation?(node)
        (node.str_type? || node.dstr_type? || node.xstr_type?) && node.source.match?(/\\\s*$/)
      end

      def range_of_first_line(range)
        begin_of_first_line = range.begin_pos - range.column
        end_of_first_line = begin_of_first_line + range.source_line.length

        Parser::Source::Range.new(range.source_buffer, begin_of_first_line, end_of_first_line)
      end

      # Expand the given range to include all of any lines it covers. Does not
      # include newline at end of the last line.
      def range_by_lines(range)
        begin_of_first_line = range.begin_pos - range.column

        last_line = range.source_buffer.source_line(range.last_line)
        last_line_offset = last_line.length - range.last_column
        end_of_last_line = range.end_pos + last_line_offset

        Parser::Source::Range.new(range.source_buffer, begin_of_first_line, end_of_last_line)
      end

      def disable_offense_at_end_of_line(range, eol_comment)
        Corrector.new(range).insert_after(range, eol_comment)
      end

      def disable_offense_before_and_after(range_by_lines)
        range_with_newline = range_by_lines.resize(range_by_lines.size + 1)
        leading_whitespace = range_by_lines.source_line[/^\s*/]

        Corrector.new(range_by_lines).wrap(
          range_with_newline,
          "#{leading_whitespace}# rubocop:todo #{cop_names.join(', ')}\n",
          "#{leading_whitespace}# rubocop:enable #{cop_names.join(', ')}\n"
        )
      end
    end
  end
end
