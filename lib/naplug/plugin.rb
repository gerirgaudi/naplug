require 'ostruct'
require 'json'

module Nagios

  module PluginMixin

    module ClassMethods
      def plugins
        @plugins
      end

      def plugin(key = nil,*args,&block)
        @plugins = {} if @plugins.nil?
        key = case
                when key.nil? then :plugin_main
                else "plugin_#{key}".to_sym
              end
        @plugins[key] = block
      end

    end

    class << self
      def included(base)
        base.extend ClassMethods
      end
    end

  end

  class Plugin

    include PluginMixin

    class JSONError < StandardError; end
    class StatusUnknown < StandardError; end
    class UninitializedPlugin < StandardError; end

    class Status

      include Comparable

      class InvalidStatus < StandardError; end

      STATUS = {
        :ok       =>  OpenStruct.new({ :i => 0, :s => 'OK',       }),
        :warning  =>  OpenStruct.new({ :i => 1, :s => 'WARNING',  }),
        :critical =>  OpenStruct.new({ :i => 2, :s => 'CRITICAL', }),
        :unknown  =>  OpenStruct.new({ :i => 3, :s => 'UNKNOWN'   })
      }

      def initialize(status = :unknown)
        raise InvalidStatus, "invalid status #{status}" unless STATUS.include?(status)
        @status = status
      end

      def to_s
        STATUS[@status].s
      end

      def to_i
        STATUS[@status].i
      end

      def method_missing(m, *args, &block)
        raise InvalidStatus, "invalid status #{m}" unless STATUS.include?(m.to_sym)
        @status = m.to_sym
      end

      def <=>(other)
        case
          when self.to_i < other.to_i then -1
          when self.to_i > other.to_i then 1
          else 0
        end
      end

    end

    class Result

      attr_accessor :status, :output, :payload, :exit_code

      def initialize(status = Status.new(:unknown), output = 'uninitialized plugin', payload = nil)
        @status = status
        @output = output
        @payload = payload
      end

      def status= (s)
        @status.send(s)
      end

      def exit_code
        @status.to_i
      end

      def to_s
        '%s: %s' % [@status,@output]
      end

    end

    STATUS = { :ok =>       Status.new(:ok),
               :warning =>  Status.new(:warning),
               :critical => Status.new(:critical),
               :unknown =>  Status.new(:unknown)
    }

    def initialize(args = {})
      @args = args
      @result = Result.new
    end

    def exec
      self.class.plugins.each_pair do |key,plugin|
        @result = instance_exec @args, &plugin
      end
    end

    def exec!
      exec
      puts single_line_output
      exit exit_code
    end

    def status
      @result.status
    end

    def output
      @result.output
    end

    def single_line_output
      '%s: %s' % [@result.status.to_s,@result.output]
    end

    def exit_code
      @result.status.to_i
    end

    def payload
      @result.payload
    end

end end