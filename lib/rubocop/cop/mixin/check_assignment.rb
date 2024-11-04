# frozen_string_literal: true

module RuboCop
  module Cop
    # Common functionality for checking assignment nodes.
    module CheckAssignment
      def on_lvasgn(node)
        check_assignment(node, node.rhs)
      end
      alias on_ivasgn   on_lvasgn
      alias on_cvasgn   on_lvasgn
      alias on_gvasgn   on_lvasgn
      alias on_casgn    on_lvasgn
      alias on_masgn    on_lvasgn
      alias on_op_asgn  on_lvasgn
      alias on_or_asgn  on_lvasgn
      alias on_and_asgn on_lvasgn

      def on_send(node)
        return unless node.last_argument

        check_assignment(node, node.last_argument)
      end

      module_function

      def extract_rhs(node)
        if node.call_type?
          node.last_argument
        else
          node.rhs
        end
      end
    end
  end
end
