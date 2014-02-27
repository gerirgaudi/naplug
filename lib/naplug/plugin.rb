require 'ostruct'

require 'naplug/status'
require 'naplug/output'
require 'naplug/performancedata'

module Naplug

  class Plugin

    attr_reader :block, :plugins, :tag, :meta

    class DuplicatePlugin < StandardError; end

    DEFAULT_META = { :debug => false, :enabled => true }
    VALID_META_OPTIONS = [ :debug, :state, :description, :parent ]

    def initialize(tag, block, meta)
      validate_meta_options meta

      @tag = tag
      @block = block
      @plugins = Hash.new

      @_args = Hash.new
      @_data = OpenStruct.new :status => Status.new, :output => Output.new, :payload => nil, :perfdata => nil
      @_meta = OpenStruct.new DEFAULT_META.merge meta

      begin
        instance_eval &block
      rescue ArgumentError => e
        raise
      rescue
        nil
      end

    end

    # @return [True, False] true if this plugin is a metaplugin, false otherwise
    def is_meta?
      @_meta.status
    end

    # enable execution of the plugin; metaplugins are always enabled
    def enable!
      is_meta? ? nil : @_meta.enabled = true
    end

    # disable execution of the plugin; metaplugins cannot be disabled
    def disable!
      is_meta? ? nil : @_meta.enabled = false
    end

    # true when plugin is enabled; false otherwise
    def is_enabled?
      @_meta.enabled
    end

    # true when the plugin is disabled; false otherwise
    def is_disabled?
      not @_meta.enabled
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
    def perfdata
      @_data.perfdata
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
      raise DuplicatePlugin, "duplicate definition of #{tag}" if @plugins.key? tag
      @plugins[tag] = Plugin.new tag, block, meta.merge({ :parent => self })
      self.define_singleton_method tag do
        @plugins[tag]
      end
    end

    def debug?
      @_meta.debug
    end

    def tagmeta_grok(tagmeta)
      case tagmeta.size
        when 0
          [:main, {}]
        when 1
          case tagmeta[0]
            when Symbol
              [tagmeta[0], {}]
            when Hash
              [:main,tagmeta[0]]
            else
              raise Naplug::Error, 'ArgumentError on Naplug#plugin'
          end
        when 2
          raise Naplug::Error, 'ArgumentError on Naplug#plugin' unless tagmeta[0].is_a? Symbol and tagmeta[1].is_a? Hash
          tagmeta[0..1]
        else
          raise Naplug::Error, 'ArgumentError on Naplug#plugin'
      end
    end

    def validate_meta_options(options)
      invalid_options = options.keys - VALID_META_OPTIONS
      if invalid_options.any?
        raise ArgumentError, "invalid meta option(s): #{invalid_options.join(', ')}"
      end
    end

  end
end
