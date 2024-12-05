# frozen_string_literal: true

RSpec.describe 'RuboCop::CLI --disable-uncorrectable', :isolated_environment do # rubocop:disable RSpec/DescribeClass
  subject(:cli) { RuboCop::CLI.new }

  include_context 'cli spec behavior'

  describe '--disable-uncorrectable' do
    let(:cli_opts) { %w[--autocorrect-all --format simple --disable-uncorrectable] }
    let(:exit_code) { cli.run(cli_opts) }

    let(:setup_long_line) do
      create_file('.rubocop.yml', <<~YAML)
        Style/IpAddresses:
          Enabled: true
        Layout/LineLength:
          Max: #{max_length}
      YAML
      create_file('example.rb', <<~RUBY)
        ip('1.2.3.4')
        # last line
      RUBY
    end
    let(:max_length) { 46 }

    it 'does not disable anything for cops that support autocorrect' do
      create_file('example.rb', 'puts 1==2')
      expect(exit_code).to eq(0)
      expect($stderr.string).to eq('')
      expect($stdout.string).to eq(<<~OUTPUT)
        == example.rb ==
        C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
        C:  1:  7: [Corrected] Layout/SpaceAroundOperators: Surrounding space missing for operator ==.
        C:  2:  1: [Corrected] Layout/EmptyLineAfterMagicComment: Add an empty line after magic comments.

        1 file inspected, 3 offenses detected, 3 offenses corrected
      OUTPUT
      expect(File.read('example.rb')).to eq(<<~RUBY)
        # frozen_string_literal: true

        puts 1 == 2
      RUBY
    end

    context 'if one one-line disable statement fits' do
      it 'adds it' do
        setup_long_line
        expect(exit_code).to eq(0)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<~OUTPUT)
          == example.rb ==
          C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
          C:  2:  1: [Corrected] Layout/EmptyLineAfterMagicComment: Add an empty line after magic comments.
          C:  3:  4: [Todo] Style/IpAddresses: Do not hardcode IP addresses.

          1 file inspected, 3 offenses detected, 3 offenses corrected
        OUTPUT
        expect(File.read('example.rb')).to eq(<<~RUBY)
          # frozen_string_literal: true

          ip('1.2.3.4') # rubocop:todo Style/IpAddresses
          # last line
        RUBY
      end

      it 'adds it when the cop supports autocorrect but does not correct the offense' do
        create_file('example.rb', <<~RUBY)
          def ordinary_method(some_arg)
            puts 'Ignoring args'
          end

          def method_with_keyword_arg(some_keyword_arg:)
            puts 'Ignoring args'
          end
        RUBY

        expect(exit_code).to eq(0)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<~OUTPUT)
          == example.rb ==
          C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
          W:  1: 21: [Corrected] Lint/UnusedMethodArgument: Unused method argument - some_arg. If it's necessary, use _ or _some_arg as an argument name to indicate that it won't be used. If it's unnecessary, remove it. You can also write as ordinary_method(*) if you want the method to accept any arguments but don't care about them.
          C:  2:  1: [Corrected] Layout/EmptyLineAfterMagicComment: Add an empty line after magic comments.
          W:  5: 29: [Todo] Lint/UnusedMethodArgument: Unused method argument - some_keyword_arg. You can also write as method_with_keyword_arg(*) if you want the method to accept any arguments but don't care about them.

          1 file inspected, 4 offenses detected, 4 offenses corrected
        OUTPUT

        expect(File.read('example.rb')).to eq(<<~RUBY)
          # frozen_string_literal: true

          def ordinary_method(_some_arg)
            puts 'Ignoring args'
          end

          def method_with_keyword_arg(some_keyword_arg:) # rubocop:todo Lint/UnusedMethodArgument
            puts 'Ignoring args'
          end
        RUBY
      end

      context 'and there are two offenses of the same kind on one line' do
        it 'adds a single one-line disable statement' do
          create_file('.rubocop.yml', <<~YAML)
            Style/IpAddresses:
              Enabled: true
          YAML
          create_file('example.rb', <<~RUBY)
            ip('1.2.3.4', '5.6.7.8')
          RUBY
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
            C:  2:  1: [Corrected] Layout/EmptyLineAfterMagicComment: Add an empty line after magic comments.
            C:  3:  4: [Todo] Style/IpAddresses: Do not hardcode IP addresses.
            C:  3: 15: [Todo] Style/IpAddresses: Do not hardcode IP addresses.

            1 file inspected, 4 offenses detected, 4 offenses corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            ip('1.2.3.4', '5.6.7.8') # rubocop:todo Style/IpAddresses
          RUBY
        end
      end

      context "but there are more offenses on the line and they don't all fit" do
        it 'adds both one-line and before-and-after disable statements' do
          create_file('example.rb', <<~RUBY)
            # Chess engine.
            class Chess
              def choose_move(who_to_move)
                legal_moves = all_legal_moves_that_dont_put_me_in_check(who_to_move)

                return nil if legal_moves.empty?

                mating_move = checkmating_move(legal_moves)
                return mating_move if mating_move

                best_moves = checking_moves(legal_moves)
                best_moves = castling_moves(legal_moves) if best_moves.empty?
                best_moves = taking_moves(legal_moves) if best_moves.empty?
                best_moves = legal_moves if best_moves.empty?
                best_moves = remove_dangerous_moves(best_moves, who_to_move)
                best_moves = legal_moves if best_moves.empty?
                best_moves.sample
              end
            end
          RUBY
          create_file('.rubocop.yml', <<~YAML)
            Metrics/AbcSize:
              Max: 15
            Metrics/CyclomaticComplexity:
              Max: 6
          YAML
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
            C:  2:  1: [Corrected] Layout/EmptyLineAfterMagicComment: Add an empty line after magic comments.
            C:  5:  3: [Todo] Metrics/AbcSize: Assignment Branch Condition size for choose_move is too high. [<8, 12, 6> 15.62/15]
            C:  5:  3: [Todo] Metrics/CyclomaticComplexity: Cyclomatic complexity for choose_move is too high. [7/6]
            C:  5:  3: [Todo] Metrics/MethodLength: Method has too many lines. [11/10]

            1 file inspected, 5 offenses detected, 5 offenses corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            # Chess engine.
            class Chess
              def choose_move(who_to_move) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength
                legal_moves = all_legal_moves_that_dont_put_me_in_check(who_to_move)

                return nil if legal_moves.empty?

                mating_move = checkmating_move(legal_moves)
                return mating_move if mating_move

                best_moves = checking_moves(legal_moves)
                best_moves = castling_moves(legal_moves) if best_moves.empty?
                best_moves = taking_moves(legal_moves) if best_moves.empty?
                best_moves = legal_moves if best_moves.empty?
                best_moves = remove_dangerous_moves(best_moves, who_to_move)
                best_moves = legal_moves if best_moves.empty?
                best_moves.sample
              end
            end
          RUBY
        end
      end
    end

    context "if a one-line disable statement doesn't fit" do
      let(:max_length) { super() - 1 }

      it 'adds before-and-after disable statement' do
        setup_long_line
        expect(exit_code).to eq(0)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<~OUTPUT)
          == example.rb ==
          C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
          C:  2:  1: [Corrected] Layout/EmptyLineAfterMagicComment: Add an empty line after magic comments.
          C:  3:  4: [Todo] Style/IpAddresses: Do not hardcode IP addresses.

          1 file inspected, 3 offenses detected, 3 offenses corrected
        OUTPUT
        expect(File.read('example.rb')).to eq(<<~RUBY)
          # frozen_string_literal: true

          # rubocop:todo Style/IpAddresses
          ip('1.2.3.4')
          # rubocop:enable Style/IpAddresses
          # last line
        RUBY
      end

      context 'and the offense is inside a heredoc' do
        it 'adds before-and-after disable statement around the heredoc' do
          create_file('example.rb', <<~'RUBY')
            # frozen_string_literal: true

            def our_function
              ourVariable = "foo"
              script = <<~JS
                <script>
                  window.stuff = "#{ourVariable}"
                </script>
              JS
              puts(script)
            end
          RUBY
          expect(exit_code).to eq(0)
          expect(File.read('example.rb')).to eq(<<~'RUBY')
            # frozen_string_literal: true

            def our_function
              ourVariable = 'foo' # rubocop:todo Naming/VariableName
              # rubocop:todo Naming/VariableName
              script = <<~JS
                <script>
                  window.stuff = "#{ourVariable}"
                </script>
              JS
              # rubocop:enable Naming/VariableName
              puts(script)
            end
          RUBY
        end
      end

      context 'and the offense is inside a percent array' do
        before do
          create_file('.rubocop.yml', <<~YAML)
            Layout/LineLength:
              Max: 30
          YAML
        end

        it 'adds before-and-after disable statement around the percent array' do
          create_file('example.rb', <<~RUBY)
            # frozen_string_literal: true

            ARRAY = %i[AAAAAAAAAAAAAAAAAAAA BBBBBBBBBBBBBBBBBBBB].freeze
          RUBY
          expect(exit_code).to eq(0)
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            # rubocop:todo Layout/LineLength
            ARRAY = %i[
              AAAAAAAAAAAAAAAAAAAA BBBBBBBBBBBBBBBBBBBB
            ].freeze
            # rubocop:enable Layout/LineLength
          RUBY
        end

        it 'adds before-and-after disable statement around the multi-line percent array' do
          create_file('example.rb', <<~RUBY)
            # frozen_string_literal: true

            ARRAY = %i[
              AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
              AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
            ].freeze
          RUBY
          expect(exit_code).to eq(0)
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            # rubocop:todo Layout/LineLength
            ARRAY = %i[
              AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
              AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
            ].freeze
            # rubocop:enable Layout/LineLength
          RUBY
        end
      end

      context 'and the offense is outside a percent array' do
        it 'adds a single one-line disable statement' do
          create_file('.rubocop.yml', <<~YAML)
            Metrics/MethodLength:
              Max: 2
          YAML
          create_file('example.rb', <<~RUBY)
            def foo
              bar do
                %w[]
              end
            end
          RUBY
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
            C:  2:  1: [Corrected] Layout/EmptyLineAfterMagicComment: Add an empty line after magic comments.
            C:  3:  1: [Todo] Metrics/MethodLength: Method has too many lines. [3/2]

            1 file inspected, 3 offenses detected, 3 offenses corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            def foo # rubocop:todo Metrics/MethodLength
              bar do
                %w[]
              end
            end
          RUBY
        end
      end

      context 'and the offense is on a line containing a string continuation' do
        it 'adds before-and-after disable statement around the string continuation' do
          create_file('.rubocop.yml', <<~YAML)
            AllCops:
              DisabledByDefault: true
            Lint/DuplicateHashKey:
              Enabled: true
          YAML
          create_file('example.rb', <<~'RUBY')
            {
              key1: 'something',
              key1: 'whatever'\
                'something else'
            }
          RUBY
          expect(exit_code).to eq(0)
          expect(File.read('example.rb')).to eq(<<~'RUBY')
            {
              key1: 'something',
              # rubocop:todo Lint/DuplicateHashKey
              key1: 'whatever'\
                'something else'
              # rubocop:enable Lint/DuplicateHashKey
            }
          RUBY
        end
      end

      context 'and the offense is on a different line than a string continuation' do
        it 'adds a single one-line disable statement' do
          create_file('.rubocop.yml', <<~YAML)
            AllCops:
              DisabledByDefault: true
            Lint/DuplicateHashKey:
              Enabled: true
          YAML
          create_file('example.rb', <<~'RUBY')
            x = 'something'\
              'something else'
            {
              key1: 'foo',
              key1: 'bar'
            }
          RUBY
          expect(exit_code).to eq(0)
          expect(File.read('example.rb')).to eq(<<~'RUBY')
            x = 'something'\
              'something else'
            {
              key1: 'foo',
              key1: 'bar' # rubocop:todo Lint/DuplicateHashKey
            }
          RUBY
        end
      end
    end

    context 'when there are multiple todos to add on the same line and ' \
            '`Style/DoubleCopDisableDirective` is disabled' do
      before do
        create_file('example.rb', <<~RUBY)
          # frozen_string_literal: true

          { foo: MyClass, foo: bar }
        RUBY

        create_file('.rubocop.yml', <<~YAML)
          Layout/LineLength:
            Max: 250
          Lint/ConstantResolution:
            Enabled: true  
          Style/DoubleCopDisableDirective:
            Enabled: false
        YAML
      end

      it 'surrounds the code with todo/enable directives' do
        expect(exit_code).to eq(0)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<~OUTPUT)
          == example.rb ==
          W:  3:  8: [Todo] Lint/ConstantResolution: Fully qualify this constant to avoid possibly ambiguous resolution.
          W:  3: 17: [Todo] Lint/DuplicateHashKey: Duplicated key in hash literal.

          1 file inspected, 2 offenses detected, 2 offenses corrected
        OUTPUT
        expect(File.read('example.rb')).to eq(<<~RUBY)
          # frozen_string_literal: true

          { foo: MyClass, foo: bar } # rubocop:todo Lint/ConstantResolution, Lint/DuplicateHashKey
        RUBY
      end
    end

    context 'when there is already a comment at the end of the line' do
      before do
        create_file('example.rb', <<~RUBY)
          # frozen_string_literal: true

          { foo: MyClass, foo: bar } # comment
        RUBY

        create_file('.rubocop.yml', <<~YAML)
          Layout/LineLength:
            Max: 250
          Lint/ConstantResolution:
            Enabled: true  
          Style/DoubleCopDisableDirective:
            Enabled: false
        YAML
      end

      it 'surrounds the code with todo/enable directives' do
        expect(exit_code).to eq(0)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<~OUTPUT)
          == example.rb ==
          W:  3:  8: [Todo] Lint/ConstantResolution: Fully qualify this constant to avoid possibly ambiguous resolution.
          W:  3: 17: [Todo] Lint/DuplicateHashKey: Duplicated key in hash literal.

          1 file inspected, 2 offenses detected, 2 offenses corrected
        OUTPUT
        expect(File.read('example.rb')).to eq(<<~RUBY)
          # frozen_string_literal: true

          # rubocop:todo Lint/ConstantResolution, Lint/DuplicateHashKey
          { foo: MyClass, foo: bar } # comment
          # rubocop:enable Lint/ConstantResolution, Lint/DuplicateHashKey
        RUBY
      end
    end

    context 'when there is already an inline todo directive' do
      before do
        create_file('example.rb', <<~RUBY)
          # frozen_string_literal: true

          { foo: MyClass, foo: bar } # rubocop:todo Lint/ConstantResolution
        RUBY

        create_file('.rubocop.yml', <<~YAML)
          Layout/LineLength:
            Max: #{max_length}
          Lint/ConstantResolution:
            Enabled: true  
          Style/DoubleCopDisableDirective:
            Enabled: false
        YAML
      end

      context 'if the line will be too long' do
        let(:max_length) { 50 }

        it 'surrounds the code with todo/enable directives' do
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            W:  3: 17: [Todo] Lint/DuplicateHashKey: Duplicated key in hash literal.

            1 file inspected, 1 offense detected, 1 offense corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            # rubocop:todo Lint/DuplicateHashKey
            { foo: MyClass, foo: bar } # rubocop:todo Lint/ConstantResolution
            # rubocop:enable Lint/DuplicateHashKey
          RUBY
        end
      end

      context 'if the line will not be too long' do
        let(:max_length) { 200 }

        it 'adds the cop to the `todo` directive' do
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            W:  3: 17: [Todo] Lint/DuplicateHashKey: Duplicated key in hash literal.

            1 file inspected, 1 offense detected, 1 offense corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            { foo: MyClass, foo: bar } # rubocop:todo Lint/ConstantResolution, Lint/DuplicateHashKey
          RUBY
        end
      end
    end

    context 'when there is already an inline disable directive' do
      before do
        create_file('example.rb', <<~RUBY)
          # frozen_string_literal: true

          { foo: MyClass, foo: bar } # rubocop:disable Lint/ConstantResolution
        RUBY

        create_file('.rubocop.yml', <<~YAML)
          Layout/LineLength:
            Max: 250
          Lint/ConstantResolution:
            Enabled: true  
          Style/DoubleCopDisableDirective:
            Enabled: false
        YAML
      end

      it 'surrounds the code with todo/enable directives' do
        expect(exit_code).to eq(0)
        expect($stderr.string).to eq('')
        expect($stdout.string).to eq(<<~OUTPUT)
          == example.rb ==
          W:  3: 17: [Todo] Lint/DuplicateHashKey: Duplicated key in hash literal.

          1 file inspected, 1 offense detected, 1 offense corrected
        OUTPUT
        expect(File.read('example.rb')).to eq(<<~RUBY)
          # frozen_string_literal: true

          # rubocop:todo Lint/DuplicateHashKey
          { foo: MyClass, foo: bar } # rubocop:disable Lint/ConstantResolution
          # rubocop:enable Lint/DuplicateHashKey
        RUBY
      end
    end

    context 'with an unsafe autocorrection' do
      let(:cli_opts) { %w[--format simple --disable-uncorrectable].unshift(autocorrect_mode) }

      before do
        create_file('example.rb', <<~RUBY)
          # frozen_string_literal: true
  
          do_something(:true)
        RUBY
      end

      context 'when `--autocorrect` is specfied' do
        let(:autocorrect_mode) { '--autocorrect' }

        it 'adds `rubocop:todo` to the offense' do
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            W:  3: 14: [Todo] Lint/BooleanSymbol: Symbol with a boolean name - you probably meant to use true.

            1 file inspected, 1 offense detected, 1 offense corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true
  
            do_something(:true) # rubocop:todo Lint/BooleanSymbol
          RUBY
        end
      end

      context 'when `--autocorrect-all` is specfied' do
        let(:autocorrect_mode) { '--autocorrect-all' }

        it 'adds corrects the offense' do
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            W:  3: 14: [Corrected] Lint/BooleanSymbol: Symbol with a boolean name - you probably meant to use true.

            1 file inspected, 1 offense detected, 1 offense corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true
  
            do_something(true)
          RUBY
        end
      end
    end

    context 'with a `Layout/SpaceInsideArrayLiteralBrackets` offense' do
      context 'when `EnforcedStyle: no_space`' do
        it 'does not disable anything for cops that support autocorrect' do
          create_file('example.rb', <<~RUBY)
            # frozen_string_literal: true

            puts [ :something ]
            # last line
          RUBY
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            C:  3:  7: [Corrected] Layout/SpaceInsideArrayLiteralBrackets: Do not use space inside array brackets.

            1 file inspected, 1 offense detected, 1 offense corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            puts [:something]
            # last line
          RUBY
        end
      end

      context 'when `EnforcedStyle: space`' do
        let(:setup_space_inside_array) do
          create_file('.rubocop.yml', <<~YAML)
            Layout/SpaceInsideArrayLiteralBrackets:
              EnforcedStyle: space
          YAML
          create_file('example.rb', <<~RUBY)
            # frozen_string_literal: true

            puts [:something]
            # last line
          RUBY
        end

        it 'does not disable anything for cops that support autocorrect' do
          setup_space_inside_array
          expect(exit_code).to eq(0)
          expect($stderr.string).to eq('')
          expect($stdout.string).to eq(<<~OUTPUT)
            == example.rb ==
            C:  3:  6: [Corrected] Layout/SpaceInsideArrayLiteralBrackets: Use space inside array brackets.

            1 file inspected, 1 offense detected, 1 offense corrected
          OUTPUT
          expect(File.read('example.rb')).to eq(<<~RUBY)
            # frozen_string_literal: true

            puts [ :something ]
            # last line
          RUBY
        end
      end
    end
  end
end
