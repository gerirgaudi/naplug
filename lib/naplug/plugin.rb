require 'ostruct'

require 'naplug/meta'
require 'naplug/status'
require 'naplug/output'
require 'naplug/performancedata'
require 'naplug/helpers/grokkers'

module Naplug

  class Plugin

    include Naplug::Helpers::Grokkers

    attr_reader :block, :plugins, :tag, :_data

    def initialize(tag, block, meta)
      @tag = tag
      @block = block
      @plugins = Hash.new

      @_args = Hash.new
      @_data = OpenStruct.new :status => Status.new, :output => Output.new, :payload => nil, :perfdata => nil
      @_meta = Meta.new meta

      begin
        instance_eval &block
      rescue ArgumentError => e
        raise
      rescue
        nil
      end

    end

    def meta
      @_meta
    end

    def parent
      @_meta.parent
    end

    def description
      @_meta.description
    end

    # true when a plugin contains plugs
    def has_plugins?
      @plugins.empty? ? false : true
    end
    alias_method :has_plugs?, :has_plugins?

    # @return [Status] plugin status
    def status
      @_data.status
    end

    # Gets plugin text output
    # @return [String] plugin text output
    def output
      @_data.output
    end

    # Sets plugin text output
    # @param text_output [String] plugin text output
    # @return [String] new plugin text output
    def output!(text_output)
      @_data.output.text_output = text_output
    end

    def long_output
      @_data.output.long_output
    end

    def long_output!(long_output)
      @_data.output.push long_output
    end

    # returns the performance data of the plugin as a PerformanceData object
    def perfdata(mode = nil)
      case mode
        when :deep
          plugins.values.map { |p| p.perfdata :deep }.push @_data.perfdata
        else
          @_data.perfdata
      end
    end

    def perfdata!(label,value,f = {})
      @_data.perfdata ||= PerformanceData.new self
      @_data.perfdata[label] = value, f
    end

    def payload
      @_data.payload
    end

    def payload!(p)
      @_data.payload = p
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

    def to_str
      '%s: %s' % [status,output]
    end

    def eval
      unless @plugins.empty?
        wcu_plugins = @plugins.values.select { |plug| plug.status.not_ok? }
        plugins = wcu_plugins.empty? ? @plugins.values : wcu_plugins
        output! plugins.map { |plug| "[#{plug.status.to_y}#{plug.tag} #{plug.output}]" }.join(' ')
        @_data.status = plugins.map { |plug| plug.status }.max
      end
    end

    private

    def plugin(*tagmeta, &block)
      tag,meta = tagmeta_grok(tagmeta)
      raise Naplug::Error, "duplicate definition of #{tag}" if @plugins.key? tag
      @plugins[tag] = Plugin.new tag, block, meta.merge({ :parent => self })
      self.define_singleton_method tag do
        @plugins[tag]
      end
    end

    def debug?
      @_meta.debug
    end

  end
end
