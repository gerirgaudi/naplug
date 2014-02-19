require 'naplug/status'

module Naplug

  class Plugin

    attr_reader :name, :block, :plugs, :tag

    class DuplicatePlugin < StandardError; end
    class UnknownPlugin < StandardError; end

    def initialize(tag, block)
      @tag = tag
      @block = block
      @plugs = Hash.new

      @_args = Hash.new
      @_status = Status.new
      @_output = 'uninitialized plugin'
      @_payload = nil

      begin; instance_eval &block ; rescue => e ; end

    end

    def has_plugs?
      @plugs.empty? ? false : true
    end

    def status
      @_status
    end

    def output
      @_output
    end

    def output!(o)
      @_output = o
    end

    def payload
      @_payload
    end

    def payload!(p)
      @_payload = p
    end

    def args
      @_args
    end

    def args!(a)
      @_args.merge! a
      @plugs.each do |tag,plug|
        plug_args = args.key?(tag) ? args[tag] : {}
        shared_args = args.select { |t,a| not @plugs.keys.include? t }
        plug.args! shared_args.merge! plug_args
      end
    end

    def [](k)
      @_args[k]
    end

    def []=(k,v)
      @_args[k] = v
    end

    def to_s
      '%s: %s' % [status,output]
    end

    def eval
      unless @plugs.empty?
        wcu_plugs = @plugs.values.select { |plug| plug.status.not_ok? }
        plugs = wcu_plugs.empty? ? @plugs.values : wcu_plugs
        @_output = plugs.map { |plug| "[#{plug.tag}@#{plug.status.to_l}: #{plug.output}]" }.join(' ')
        @_status = plugs.map { |plug| plug.status }.max
      end
    end

    private

    def plug(tag, &block)
      raise DuplicatePlugin, "duplicate definition of #{tag}" if @plugs.key? tag
      @plugs[tag] = Plugin.new tag, block
      self.define_singleton_method tag do
        @plugs[tag]
      end
    end

  end
end
