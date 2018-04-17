module Naplug

  class Output
    # Implements Text Output and Long Text elements from the Nagios Plugin API
    # * Nagios v3: http://nagios.sourceforge.net/docs/nagioscore/3/en/pluginapi.html
    # * Nagios v4: http://nagios.sourceforge.net/docs/nagioscore/4/en/pluginapi.html

    attr_accessor :text_output
    attr_reader :long_text

    def initialize(text_output = 'uninitialized plugin')
      @text_output = text_output
      @long_text = []
    end

    # Pushes the given long text strings on the end of long text. Returns the long_text
    # @return [Array<String>] array of long text strings
    def push(*long_text)
      @long_text.push long_text
    end

    def to_s(output = :text_output)
      case output
        when :text_output then @text_output
        when :long_text   then @long_text.join "\n"
        else nil
      end
    end

  end
end