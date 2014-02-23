require 'ostruct'

require 'naplug/status'
require 'naplug/output'
require 'naplug/performancedata'

module Naplug

  class Plugin

    attr_reader :block, :plugins, :tag

    class DuplicatePlugin < StandardError; end

    def initialize(tag, meta = false, block)
      @tag = tag
      @block = block
      @plugins = Hash.new

      @_args = Hash.new
      @_data = OpenStruct.new :status => Status.new, :output => Output.new, :payload => nil, :perfdata => nil
      @_meta = OpenStruct.new :status => meta, :enabled => true, :debug => true

      begin; instance_eval &block ; rescue => e; nil ; end

    end

    # @param format [Symbol] the format type, `:text` or `:html`
    # @return [True, False<String>, nil] the object or objects to
    #   find in the database. Can be nil.@return [String] the object converted into the expected format.
    # # true if this plugin is a metaplugin, false otherwise
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
      @_data.perfdata ||= PerformanceData.new @tag
      @_data.perfdata.store label, value, f
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

    def to_s
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

    def plugin(tag, &block)
      raise DuplicatePlugin, "duplicate definition of #{tag}" if @plugins.key? tag
      @plugins[tag] = Plugin.new tag, block
      self.define_singleton_method tag do
        @plugins[tag]
      end
    end

    def debug?
      @_meta.debug
    end

  end
end
