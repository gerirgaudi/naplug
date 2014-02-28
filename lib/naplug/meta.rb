require 'benchmark'

module Naplug

  class Meta

    DEFAULT = { :debug => false, :state => true, :description => '', :parent => nil, :benchmark => nil, :meta => true }
    OPTIONS = DEFAULT.keys

    def initialize(meta = DEFAULT)
      validate meta
      @meta = DEFAULT.merge meta
      @meta[:benchmark] = Benchmark::Tms.new if @meta[:benchmark]
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

    def validate(meta)
      invalid_options = meta.keys - OPTIONS
      raise Naplug::Error, "invalid meta option(s): #{invalid_options.join(', ')}" if invalid_options.any?

      # benchmark is allowed to be nil, false, true, or a Benchmark::Tms object
      case meta[:benchmark]
        when nil, true, false, Benchmark::Tms
          true
        else
          raise Naplug::Error, "invalid benchmark metadata: #{meta[:benchmark].class.to_s}"
        end
    end
  end

end