# frozen_string_literal: true

module FunCi
  module Contract
    # The SGR state a terminal carries from one escape to the next: a
    # foreground colour index (nil for the default), bold and dim.
    SgrStyle = Data.define(:fg, :bold, :dim) do
      def self.default = new(fg: nil, bold: false, dim: false)

      def default? = self == self.class.default

      def apply(params)
        tokens = params.scan(/38;5;\d+|\d+/)
        tokens = ["0"] if tokens.empty?
        tokens.reduce(self) { |style, token| style.step(token) }
      end

      def step(token)
        return with(fg: token.split(";").last.to_i) if token.start_with?("38;")

        code = token.to_i
        return with(fg: SgrStyle::COLOURS.fetch(code)) unless SgrStyle::ATTRIBUTES.key?(code)

        SgrStyle::ATTRIBUTES[code].call(self)
      end

      def to_json_h
        { "fg" => fg, "bold" => bold, "dim" => dim }.select { |_, value| value }
      end
    end

    SgrStyle::ATTRIBUTES = {
      0 => ->(_) { SgrStyle.default }, 1 => ->(s) { s.with(bold: true) }, 2 => ->(s) { s.with(dim: true) }
    }.freeze
    SgrStyle::COLOURS = (30..37).to_h { |code| [code, code - 30] }
                                .merge((90..97).to_h { |code| [code, code - 82] }, 39 => nil).freeze
  end
end
