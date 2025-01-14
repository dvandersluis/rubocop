# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::RedundantToS, :config do
  it 'does not register an offense when calling `to_s` without a receiver' do
    expect_no_offenses(<<~RUBY)
      to_s
    RUBY
  end

  it 'does not register an offense when calling `to_s` on `self`' do
    expect_no_offenses(<<~RUBY)
      self.to_s
    RUBY
  end

  it 'does not register an offense when calling `to_s` on an identifier' do
    expect_no_offenses(<<~RUBY)
      foo.to_s
    RUBY
  end

  it 'does not register an offense when calling `to_s` with arguments on an identifier' do
    expect_no_offenses(<<~RUBY)
      foo.to_s(2)
    RUBY
  end

  it 'does not register an offense when calling `to_s` on an symbol' do
    expect_no_offenses(<<~RUBY)
      :sym.to_s
    RUBY
  end

  it 'does not register an offense when calling `to_s` on an integer' do
    expect_no_offenses(<<~RUBY)
      1.to_s
    RUBY
  end

  it 'does not register an offense when calling `to_s` on an array' do
    expect_no_offenses(<<~RUBY)
      [].to_s
    RUBY
  end

  it 'does not register an offense when calling `to_s` on an local variable named `to_s`' do
    expect_no_offenses(<<~RUBY)
      to_s = foo
      to_s.to_s
    RUBY
  end

  it 'does not register an offense when calling `to_s` on a parenthesized method call' do
    expect_no_offenses(<<~RUBY)
      (foo).to_s
    RUBY
  end

  it 'does not register an offense when calling on parenthesized code containing a string' do
    expect_no_offenses(<<~RUBY)
      (foo + 'bar').to_s
    RUBY
  end

  it 'does not register an offense when calling on parenthesized `foo.to_s` chained with another method' do
    expect_no_offenses(<<~RUBY)
      (foo.to_s).bar
    RUBY
  end

  context 'when calling `to_s` on a string' do
    it 'registers an offense and corrects with a single quoted string literal' do
      expect_offense(<<~RUBY)
        'string'.to_s
                 ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        'string'
      RUBY
    end

    it 'registers an offense and corrects with a double quoted string literal' do
      expect_offense(<<~RUBY)
        "string".to_s
                 ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        "string"
      RUBY
    end

    it 'registers an offense and corrects with an interpolated string' do
      expect_offense(<<~'RUBY')
        "#{string}".to_s
                    ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~'RUBY')
        "#{string}"
      RUBY
    end

    it 'registers an offense and corrects with a %{} string' do
      expect_offense(<<~RUBY)
        %{string}.to_s
                  ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        %{string}
      RUBY
    end

    it 'registers an offense and corrects with a %q{} string' do
      expect_offense(<<~RUBY)
        %q{string}.to_s
                   ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        %q{string}
      RUBY
    end

    it 'registers an offense and corrects with a %Q{} string' do
      expect_offense(<<~RUBY)
        %Q{string}.to_s
                   ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        %Q{string}
      RUBY
    end

    it 'registers an offense and corrects with `String.new`' do
      expect_offense(<<~RUBY)
        String.new('string').to_s
                             ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        String.new('string')
      RUBY
    end

    it 'registers an offense and corrects with `::String.new`' do
      expect_offense(<<~RUBY)
        ::String.new('string').to_s
                               ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        ::String.new('string')
      RUBY
    end

    it 'registers an offense and corrects with a heredoc' do
      expect_offense(<<~RUBY)
        <<~STR.to_s
               ^^^^ Redundant `to_s` detected.
          string
        STR
      RUBY

      expect_correction(<<~RUBY)
        <<~STR
          string
        STR
      RUBY
    end

    it 'registers an offense and corrects when the redundant `to_s` is chained further' do
      expect_offense(<<~RUBY)
        'string'.to_s.bar
                 ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        'string'.bar
      RUBY
    end

    it 'registers an offense for a string wrapped in parens' do
      expect_offense(<<~RUBY)
        ('string').to_s
                   ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        ('string')
      RUBY
    end

    it 'registers an offense for a string wrapped in multiple parens' do
      expect_offense(<<~RUBY)
        (('string')).to_s
                     ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        (('string'))
      RUBY
    end
  end

  context 'when chaining `to_s` calls' do
    it 'registers an offense and corrects when calling `to_s` on a `to_s` call' do
      expect_offense(<<~RUBY)
        foo.to_s.to_s
                 ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        foo.to_s
      RUBY
    end

    it 'registers an offense and corrects when calling `to_s` on a `to_s` call with safe navigation' do
      expect_offense(<<~RUBY)
        foo&.to_s&.to_s
                   ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        foo&.to_s
      RUBY
    end

    it 'registers an offense and corrects when calling `to_s` on a `to_s` call with an argument' do
      expect_offense(<<~RUBY)
        foo.to_s(2).to_s
                    ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        foo.to_s(2)
      RUBY
    end

    it 'registers an offense and corrects when calling `to_s` on a `to_s` call with an argument and safe navigation' do
      expect_offense(<<~RUBY)
        foo&.to_s(2)&.to_s
                      ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        foo&.to_s(2)
      RUBY
    end

    it 'registers an offense and corrects when calling `to_s` on a `to_s` call on an integer with an argument' do
      expect_offense(<<~RUBY)
        10.to_s(2).to_s
                   ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        10.to_s(2)
      RUBY
    end

    it 'registers an offense and corrects when the redundant `to_s` is chained further' do
      expect_offense(<<~RUBY)
        foo.to_s.to_s.bar
                 ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        foo.to_s.bar
      RUBY
    end

    it 'registers an offense and corrects when the redundant `to_s` is chained further with safe navigation' do
      expect_offense(<<~RUBY)
        foo&.to_s&.to_s&.bar
                   ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        foo&.to_s&.bar
      RUBY
    end

    it 'registers an offense for a `to_s` call wrapped in parens' do
      expect_offense(<<~RUBY)
        (foo.to_s).to_s
                   ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        (foo.to_s)
      RUBY
    end

    it 'registers an offense for a `to_s` call wrapped in multiple parens' do
      expect_offense(<<~RUBY)
        ((foo.to_s)).to_s
                     ^^^^ Redundant `to_s` detected.
      RUBY

      expect_correction(<<~RUBY)
        ((foo.to_s))
      RUBY
    end
  end
end
