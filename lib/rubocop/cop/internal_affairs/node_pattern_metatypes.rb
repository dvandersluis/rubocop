# frozen_string_literal: true

module RuboCop
  module Cop
    module InternalAffairs
      # Use node metatypes (`argument`, `boolean`, `call`, `numeric`, `range`) in node
      # patterns instead of a union (`{ ... }`) of the member types of the metatype.
      #
      # @example
      #   # bad
      #   def_node_matcher :my_matcher, <<~PATTERN
      #     {send csend}
      #   PATTERN
      #
      #   # good
      #   def_node_matcher :my_matcher, <<~PATTERN
      #     call
      #   PATTERN
      #
      class NodePatternMetatypes < Base
        require_relative 'node_pattern_metatypes/metatype_processor'

        include RangeHelp
        extend AutoCorrector

        MSG = 'Replace `%<names>s` in node pattern union with `%<replacement>s`.'
        RESTRICT_ON_SEND = %i[def_node_matcher def_node_search].freeze
        METATYPES = {
          argument: %i[arg optarg restarg kwarg kwoptarg kwrestarg blockarg forward_arg shadowarg],
          boolean: %i[true false],
          call: %i[send csend],
          numeric: %i[int float rational complex],
          range: %i[irange erange]
        }.freeze

        def on_new_investigation
          @processor = MetatypeProcessor.new
        end

        # When a node pattern matcher is defined, investigate the node pattern to search
        # for node types that can be replaced with a metatype (ie. `{send csend}` can be
        # replaced with `call`).
        #
        # In order to deal with node patterns in an efficient and non-brittle way, we will
        # parse the node pattern given to this `send` node using
        # `RuboCop::AST::NodePattern::Parser::WithMeta`, and then run the resulting AST
        # through a processor to find the nodes to remove. `WithMeta` is important! We need
        # location information so that we can calculate the exact locations within the
        # pattern to report and correct.
        #
        #
        def on_send(node)
          pattern_node = node.arguments[1]
          return unless acceptable_heredoc?(pattern_node) || pattern_node.str_type?

          process_pattern(pattern_node)
          return if @processor.metatypes.nil?

          apply_range_offsets(pattern_node)

          @processor.metatypes.each do |metatype|
            register_offense(pattern_node, metatype)
          end
        end

        def after_send(_)
          @processor.reset!
        end

        private

        # rubocop:disable Metrics/AbcSize
        def apply_range_offsets(pattern_node)
          range, offset = range_with_offset(pattern_node)

          @processor.metatypes.each do |data|
            data.ranges ||= []
            data.offense_range = pattern_range(range, data.union, offset)

            if data.other_elements.any?
              data.node_types.each do |node_type|
                data.ranges << pattern_range(range, node_type, offset)
              end
            else
              data.ranges << data.offense_range
            end
          end
        end
        # rubocop:enable Metrics/AbcSize

        def register_offense(pattern_node, metatype)
          message = format(
            MSG,
            names: metatype.node_type_names.join('`, `'),
            replacement: metatype.name
          )

          add_offense(metatype.offense_range, message: message) do |corrector|
            if metatype.other_elements.any?
              replace_types_with_metatype(corrector, pattern_node, metatype)
            else
              replace_union(corrector, metatype)
            end
          end
        end

        def replace_types_with_metatype(corrector, pattern_node, metatype)
          # When there are other elements in the union, remove the node types
          # that can be replaced
          ranges = metatype.ranges.map.with_index do |range, index|
            range_with_surrounding_space(range: range, side: :left, newlines: index.positive?)
          end

          ranges.each { |range| corrector.remove(range) }

          insertion = "#{padding(pattern_node, metatype, ranges.first.last_line)}#{metatype.name}"
          corrector.insert_before(ranges.first, insertion)
        end

        def replace_union(corrector, metatype)
          # When there are no other elements, the entire union can be replaced
          corrector.replace(metatype.ranges.first, metatype.name)
        end

        def pattern_range(range, node, offset)
          begin_pos = node.source_range.begin_pos
          end_pos = node.source_range.end_pos
          size = end_pos - begin_pos

          range.adjust(begin_pos: begin_pos + offset).resize(size)
        end

        def range_with_offset(pattern_node)
          if pattern_node.heredoc?
            [pattern_node.loc.heredoc_body, 0]
          else
            [pattern_node.source_range, 1]
          end
        end

        def acceptable_heredoc?(node)
          # A heredoc can be a `dstr` without interpolation, but if there is interpolation
          # there'll be a `begin` node, in which case, we cannot evaluate the pattern.
          node.type?(:str, :dstr) && node.heredoc? && node.each_child_node(:begin).none?
        end

        def process_pattern(pattern_node)
          parser = RuboCop::AST::NodePattern::Parser::WithMeta.new
          ast = parser.parse(pattern_value(pattern_node))
          @processor.process(ast)
        rescue RuboCop::AST::NodePattern::Invalid
          # if the pattern is invalid, no offenses will be registered
        end

        def pattern_value(pattern_node)
          pattern_node.heredoc? ? pattern_node.loc.heredoc_body.source : pattern_node.value
        end

        def padding(pattern_node, metatype, line)
          # If the first node type being removed wasn't the first in the union,
          # add a space before it.
          if pattern_node.heredoc?
            line = processed_source.lines[line - 1]
            line[/^\s*/]
          elsif metatype.start_index.positive?
            ' '
          end
        end
      end
    end
  end
end
