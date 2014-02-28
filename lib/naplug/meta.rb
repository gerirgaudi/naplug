module Naplug

  class Meta

    DEFAULT = { :debug => false, :state => true, :description => '', :parent => nil, :benchmark => nil, :meta => true }
    OPTIONS = DEFAULT.keys

    def initialize(meta = DEFAULT)
      validate meta
      @meta = DEFAULT.merge meta
    end

    OPTIONS.each do |option|
      define_method option do
        @meta[option]
      end
      define_method "#{option}!".to_sym do |m|
        @meta[option] = m
      end
    end

    def to_h
      @meta
    end

    private

    def validate(options)
      invalid_options = options.keys - OPTIONS
      raise Naplug::Error, "invalid meta option(s): #{invalid_options.join(', ')}" if invalid_options.any?
    end

  end

end