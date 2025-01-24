# frozen_string_literal: true

RSpec.describe RuboCop::Cop::InternalAffairs::NodePatternMetatypes, :config do
  # `call` will be used to test edge cases, the other
  # metatypes will just test that they replace properly below

  it 'can handle an invalid pattern' do
    expect_no_offenses(<<~RUBY)
      def_node_matcher :my_matcher, <<~PATTERN
        ({send csend
      PATTERN
    RUBY
  end

  describe '`call` metatype' do
    it 'does not register an offense for `call`' do
      expect_no_offenses(<<~RUBY)
        def_node_matcher :my_matcher, 'call'
      RUBY
    end

    it 'does not register an offense for `(call)`' do
      expect_no_offenses(<<~RUBY)
        def_node_matcher :my_matcher, '(call)'
      RUBY
    end

    it 'does not register an offense for `{send def}`' do
      expect_no_offenses(<<~RUBY)
        def_node_matcher :my_matcher, '{send def}'
      RUBY
    end

    it 'does not register an offense for `{csend def}`' do
      expect_no_offenses(<<~RUBY)
        def_node_matcher :my_matcher, '{csend def}'
      RUBY
    end

    it 'does not register an offense for `{call def}`' do
      expect_no_offenses(<<~RUBY)
        def_node_matcher :my_matcher, '{call def}'
      RUBY
    end

    it 'does not register an offense for a dynamic pattern' do
      expect_no_offenses(<<~'RUBY')
        def_node_matcher :my_matcher, '{ #{TYPES.join(' ')} }'
      RUBY
    end

    it 'registers an offense and corrects `{send csend}`' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '{send csend}'
                                       ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, 'call'
      RUBY
    end

    it 'registers an offense and corrects `{csend send}`' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '{csend send}'
                                       ^^^^^^^^^^^^ Replace `csend`, `send` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, 'call'
      RUBY
    end

    it 'registers an offense and corrects `({send csend})`' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '({send csend})'
                                        ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, '(call)'
      RUBY
    end

    it 'registers an offense and corrects `{(send) (csend)}`' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '{(send) (csend)}'
                                       ^^^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, 'call'
      RUBY
    end

    it 'registers an offense and corrects `{send csend def}`' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '{send csend def}'
                                       ^^^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, '{call def}'
      RUBY
    end

    it 'registers an offense and corrects `{send def csend}`' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '{send def csend}'
                                       ^^^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, '{call def}'
      RUBY
    end

    it 'registers an offense and corrects `{def send csend}`' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '{def send csend}'
                                       ^^^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, '{def call}'
      RUBY
    end

    it 'registers an offense and corrects `{send csend (def _ :foo)}`' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '{send csend (def _ :foo)}'
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, '{call (def _ :foo)}'
      RUBY
    end

    it 'registers an offense and corrects multiple unions inside a node' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, <<~PATTERN
          ({send csend} {send csend} ...)
                        ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
           ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
        PATTERN
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, <<~PATTERN
          (call call ...)
        PATTERN
      RUBY
    end

    it 'registers an offense and corrects a complex pattern' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, '({send csend} (const {nil? cbase} :FileUtils) :cd ...)'
                                        ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, '(call (const {nil? cbase} :FileUtils) :cd ...)'
      RUBY
    end

    it 'registers offenses when there are multiple matchers' do
      expect_offense(<<~RUBY)
        def_node_matcher :matcher1, <<~PATTERN
          {send csend}
          ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
        PATTERN

        def_node_matcher :matcher2, <<~PATTERN
          (send nil !nil?)
        PATTERN

        def_node_matcher :matcher3, <<~PATTERN
          (send {send csend} _ :foo)
                ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
        PATTERN
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :matcher1, <<~PATTERN
          call
        PATTERN

        def_node_matcher :matcher2, <<~PATTERN
          (send nil !nil?)
        PATTERN

        def_node_matcher :matcher3, <<~PATTERN
          (send call _ :foo)
        PATTERN
      RUBY
    end

    context 'in heredoc' do
      it 'does not register an offense for `call`' do
        expect_no_offenses(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            call
          PATTERN
        RUBY
      end

      it 'does not register an offense for a dynamic pattern' do
        expect_no_offenses(<<~'RUBY')
          def_node_matcher :my_matcher, <<~PATTERN
            { #{TYPES.join(' ')} }
          PATTERN
        RUBY
      end

      it 'registers an offense and corrects `{send csend}`' do
        expect_offense(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {csend send}
            ^^^^^^^^^^^^ Replace `csend`, `send` in node pattern union with `call`.
          PATTERN
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            call
          PATTERN
        RUBY
      end

      it 'registers an offense and corrects `{send csend}` on multiple lines' do
        expect_offense(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {csend
            ^^^^^^ Replace `csend`, `send` in node pattern union with `call`.
            send}
          PATTERN
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            call
          PATTERN
        RUBY
      end

      it 'registers an offense and corrects `{send csend (def _ :foo)}` in a multiline heredoc' do
        expect_offense(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {
            ^ Replace `send`, `csend` in node pattern union with `call`.
              send
              csend
              (def _ :foo)
            }
          PATTERN
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {
              call
              (def _ :foo)
            }
          PATTERN
        RUBY
      end

      it 'registers an offense and corrects `{(def _ :foo) send csend}` in a multiline heredoc' do
        expect_offense(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {
            ^ Replace `send`, `csend` in node pattern union with `call`.
              (def _ :foo)
              send
              csend
            }
          PATTERN
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {
              (def _ :foo)
              call
            }
          PATTERN
        RUBY
      end
    end

    context 'union with pipes' do
      it 'registers an offense and corrects `{send | csend}`' do
        expect_offense(<<~RUBY)
          def_node_matcher :my_matcher, '{send | csend}'
                                         ^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, 'call'
        RUBY
      end

      it 'registers an offense and corrects `{send | csend | def}`', pending: 'TODO' do
        expect_offense(<<~RUBY)
          def_node_matcher :my_matcher, '{send | csend | def}'
                                         ^^^^^^^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, '{ call | def }'
        RUBY
      end

      it 'does not register an offense for `({send ... csend | def})`' do
        expect_no_offenses(<<~RUBY)
          def_node_matcher :my_matcher, '({send ... csend | def})'
        RUBY
      end

      it 'registers an offense for `({send | csend | send ... csend | def})`', pending: 'TODO' do
        expect_offense(<<~RUBY)
          def_node_matcher :my_matcher, '({send | csend | send ... csend | def})'
                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, '({call | send ... csend | def})'
        RUBY
      end
    end

    context 'with arguments', pending: 'TODO' do
      it 'registers an offense and corrects when the arguments match' do
        expect_offense(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {(send _ :foo) (csend _ :foo)}
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
          PATTERN
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            (call _ :foo)
          PATTERN
        RUBY
      end

      it 'does not register an offense if one node has arguments and the other does not' do
        expect_no_offenses(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {send (csend _ :foo)}
          PATTERN
        RUBY
      end

      it 'does not register an offense if when the nodes have different arguments' do
        expect_no_offenses(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            {(send _ :foo) (csend _ :bar)}
          PATTERN
        RUBY
      end
    end
  end

  context 'with nested unions' do
    it 'registers an offense and corrects for a union inside a union' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, <<~PATTERN
          {lvar {send csend} def}
                ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
        PATTERN
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, <<~PATTERN
          {lvar call def}
        PATTERN
      RUBY
    end

    it 'registers an offense and corrects for a union inside a node type' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, <<~PATTERN
          (send {send csend} ...)
                ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
        PATTERN
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, <<~PATTERN
          (send call ...)
        PATTERN
      RUBY
    end

    it 'registers an offense and corrects for a union inside a node type inside a union' do
      expect_offense(<<~RUBY)
        def_node_matcher :my_matcher, <<~PATTERN
          {
            (send {send csend} ...)
                  ^^^^^^^^^^^^ Replace `send`, `csend` in node pattern union with `call`.
            def
          }
        PATTERN
      RUBY

      expect_correction(<<~RUBY)
        def_node_matcher :my_matcher, <<~PATTERN
          {
            (send call ...)
            def
          }
        PATTERN
      RUBY
    end
  end

  shared_examples 'metatype' do |metatype, group|
    describe "`#{metatype}` metatype" do
      let(:source) { group.join(' ') }
      let(:names) { group.join('`, `') }

      it 'registers an offense and corrects' do
        expect_offense(<<~RUBY, source: source)
          def_node_matcher :my_matcher, '{%{source}}'
                                         ^^{source}^ Replace `#{names}` in node pattern union with `#{metatype}`.
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, '#{metatype}'
        RUBY
      end

      it 'registers an offense and corrects with a heredoc' do
        expect_offense(<<~RUBY, source: source)
          def_node_matcher :my_matcher, <<~PATTERN
            {%{source}}
            ^^{source}^ Replace `#{names}` in node pattern union with `#{metatype}`.
          PATTERN
        RUBY

        expect_correction(<<~RUBY)
          def_node_matcher :my_matcher, <<~PATTERN
            #{metatype}
          PATTERN
        RUBY
      end
    end
  end

  it_behaves_like 'metatype', 'argument',
                  %i[arg blockarg forward_arg kwarg kwoptarg kwrestarg optarg restarg shadowarg]
  it_behaves_like 'metatype', 'boolean', %i[false true]
  it_behaves_like 'metatype', 'numeric', %i[complex float int rational]
  it_behaves_like 'metatype', 'range', %i[erange irange]
end
