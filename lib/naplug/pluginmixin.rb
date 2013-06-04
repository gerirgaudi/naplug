module Nagios

  module PluginMixin

    class Plug

      attr_reader :tag, :block
      attr_accessor :args, :output, :payload

      def initialize(tag, block, args = {})
        @tag = tag
        @args = args
        @block = block
        @_status = Status.new :unknown
        @output = 'uninitialized plug'
        @payload = nil
      end

      def status= (s)
        @_status.send(:set, s)
      end

      def status
        @_status
      end

    end

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
        self.set(status)
      end

      def to_s
        STATUS[@status].s
      end

      def to_i
        STATUS[@status].i
      end

      def set(status)
        raise InvalidStatus, "invalid status #{status}" unless STATUS.include?(status)
        @status = status.to_sym
      end

      def <=>(other)
        case
          when self.to_i < other.to_i then -1
          when self.to_i > other.to_i then 1
          else 0
        end
      end

    end

  end

end