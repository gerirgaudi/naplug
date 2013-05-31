module Nagios

  module PluginMixin

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
        @status = status.to_sym
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

  end

end