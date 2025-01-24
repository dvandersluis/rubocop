# frozen_string_literal: true

module RuboCop
  module Cop
    module InternalAffairs
      class NodePatternMetatypes
        # AST Processor for finding unions within a Node Pattern that can have some or
        # all of its `node_type` elements replaced by a `RuboCop::AST` metatype
        # (eg. `call`, `range`, etc.).
        #
        # Usage:
        #   - instantiate a MetatypeProcessor:
        #     `processor = MetatypeProcessor.new`
        #   - parse a node pattern into an AST using `RuboCop::AST::NodePattern::Parser`, or
        #     one of its variants.
        #   - call `processor.process(ast)` on the result of the parser
        #   - detected metatype struct data is available via `processor.metatypes`
        #
        # NOTE: the AST nodes being processed here are `RuboCop::AST::NodePattern::Node`
        # instances, not `RuboCop::AST::Node`. There is a reduced set of functionality for
        # these nodes than we are normally afforded!
        #
        # NOTE: The `on_*` methods in this class relate not to the normal node types but
        # rather to the Node Pattern node types. Not every node type is handled.
        #
        class MetatypeProcessor
          include ::AST::Processor::Mixin

          Metatype = Struct.new(
            :name, :node_types, :node_type_names, :start_index, :offense_range, :ranges,
            :union, :other_elements
          )

          attr_reader :metatypes

          def initialize
            reset!
          end

          def reset!
            @metatypes = []
            @current_union = nil
            @node_types = {}
          end

          def handler_missing(node)
            process_all(node.child_nodes)
          end

          def on_sequence(sequence_node)
            process_all(sequence_node.child_nodes)
          end

          def on_union(union_node)
            # NodePattern nodes do not have ancestor hierarchy, so keep track of the current
            # `union` node so that `node_type` nodes within it can be associated correctly.
            # NOTE: `union`s can contain other `union`s.

            prev_union = @current_union
            @current_union = union_node

            process_all(union_node.child_nodes)
            process_node_types_in_union(union_node)
          ensure
            @current_union = prev_union
          end

          def on_subsequence(subsequence_node)
            # Subsequences are ignored inside `union`s so that `node_type`s within
            # a subsequence aren't erroneously considered.
            # TODO: a subsequence can contain another union!
            subsequence_node.updated(:subsequence, [:ignored]) if current_union
          end

          def on_node_type(node_type_node)
            (node_types[current_union] ||= []) << node_type_node if current_union
          end

          private

          attr_accessor :current_union, :node_types

          # rubocop:disable Metrics/AbcSize
          def process_node_types_in_union(union_node)
            types = node_types[current_union].to_h { |node| [node.child, node] }

            return unless (metatype_name = metatype_name(types.keys))

            # It is important to retain the order of types so that the offense message is correct
            relevant_keys = METATYPES[metatype_name].sort_by { |type| types.keys.index(type) }
            relevant_node_types = types.slice(*relevant_keys)

            other = types.except(*relevant_node_types.keys)
            start_index = types.keys.index(relevant_node_types.keys.first)

            metatypes << metatype_data(
              metatype_name, relevant_node_types, start_index, union_node, other
            )
          ensure
            node_types[current_union] = nil
          end
          # rubocop:enable Metrics/AbcSize

          def metatype_name(types_to_check)
            METATYPES.detect { |_, group| group & types_to_check == group }&.first
          end

          def metatype_data(name, node_types, start_index, union, other)
            Metatype.new(
              name: name,
              node_types: node_types.values,
              node_type_names: node_types.keys,
              start_index: start_index,
              union: union,
              other_elements: other.values
            )
          end
        end
      end
    end
  end
end
