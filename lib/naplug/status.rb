require 'ostruct'

module Naplug

  class Status

    include Comparable

    class InvalidStatus < StandardError; end

    STATUS = {
        :ok       =>  OpenStruct.new({ :i => 0, :s => 'OK',       :y => '+' }),
        :warning  =>  OpenStruct.new({ :i => 1, :s => 'WARNING',  :y => '-' }),
        :critical =>  OpenStruct.new({ :i => 2, :s => 'CRITICAL', :y => '!' }),
        :unknown  =>  OpenStruct.new({ :i => 3, :s => 'UNKNOWN',  :y => '*' })
    }

    def self.states
      STATUS.keys
    end

    def initialize(state = :unknown)
      @status = state
    end

    STATUS.keys.each do |state|
      define_method "#{state}!".to_sym do
        @status = state
      end
    end

    STATUS.keys.each do |state|
      define_method "#{state}?".to_sym do
        @status == state ? true : false
      end
      define_method "not_#{state}?".to_sym do
        @status == state ? false : true
      end
    end

    def to_s
      STATUS[@status].s
    end

    def to_i
      STATUS[@status].i
    end

    def to_y
      STATUS[@status].y
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