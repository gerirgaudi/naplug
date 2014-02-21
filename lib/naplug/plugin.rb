require 'naplug/status'
require 'naplug/performancedata'

module Naplug

  class Plugin

    attr_reader :name, :block, :plugins, :tag

    class DuplicatePlugin < StandardError; end

    def initialize(tag, block)
      @tag = tag
      @block = block
      @plugins = Hash.new

      @_args = Hash.new
      @_args = Hash.new
      @_status = Status.new
      @_output = 'uninitialized plugin'
      @_payload = nil
      @_perfdata = nil

      begin; instance_eval &block ; rescue => e ; end

    end

    def has_plugins?
      @plugins.empty? ? false : true
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

    def perfdata
      @_perfdata
    end

    def perfdata!(label,value,f = {})
      @_perfdata ||= PerformanceData.new @tag
      @_perfdata.store label, value, f
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

    def args!(args)
      @_args.merge! args
      @plugins.each do |tag,plug|
        plug_args = args.key?(tag) ? args[tag] : {}
        shared_args = args.select { |t,a| not @plugins.keys.include? t }
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
      unless @plugins.empty?
        wcu_plugins = @plugins.values.select { |plug| plug.status.not_ok? }
        plugins = wcu_plugins.empty? ? @plugins.values : wcu_plugins
        @_output = plugins.map { |plug| "[#{plug.status.to_y}#{plug.tag} #{plug.output}]" }.join(' ')
        @_status = plugins.map { |plug| plug.status }.max
      end
    end

    private

    def plugin(tag, &block)
      raise DuplicatePlugin, "duplicate definition of #{tag}" if @plugins.key? tag
      @plugins[tag] = Plugin.new tag, block
      self.define_singleton_method tag do
        @plugins[tag]
      end
    end

  end
end
