#--
#
# Author:: Gerir Lopez-Fernandez
# Homepage::  https://github.com/gerirgaudi/naplug/
# Date:: 25 Feb 2014
#
# See the file LICENSE for licensing information.
#
#---------------------------------------------------------------------------

#--
# Naplug::ClassMethods and Naplug::InstanceMethods

require 'naplug/meta'
require 'naplug/plugin'
require 'naplug/helpers/grokkers'

module Naplug

  class Error < StandardError; end

  module ClassMethods

    include Naplug::Helpers::Grokkers

    # @!scope class

    # @!attribute [r] plugins
    #   @return [Hash<Symbol, Plugin>] metaplugins
    attr_reader :plugins

    # Create a metaplugin (which basically contains a tag and a block)
    # @param tag [Symbol] the plugin tag
    # @return [Plugin] a metaplugin
    def plugin(*tagmeta, &block)
      tag, meta = tagmeta_grok tagmeta
      @metas = Hash.new unless @metas
      @metas[tag] = Meta.new meta.merge :meta => true
      @plugins = Hash.new unless @plugins
      @plugins[tag] = create_metaplugin tag, meta, block
      @_time = { :start => Time.now } #  if m[:benchmark]
    end

    def meta(m)
      @_time = { :start => Time.now } #  if m[:benchmark]
    end

    # A list of plugin tags
    # @return [Array<Symbol>] the list of plugin tags
    def tags
      self.plugins.keys
    end

    private

    # Create a metaplugin (helper)
    def create_metaplugin(tag,meta,block)
      module_eval do
        define_method "#{tag}".to_sym  do; @plugins[tag];  end    # <tag> methods for quick access to plugins
        define_method "#{tag}!".to_sym do; self.exec! tag; end    # <tag>! methods to involke exec! on a given plugin
      end
      Plugin.new tag, block, meta.merge(:parent => self, :meta => true)
    end

  end

  module InstanceMethods

    # @!scope instancce

    attr_reader :plugins

    def initialize(args = {})
      @plugins = Hash.new
      plugins!

      @_args = Hash.new
      args! args
    end

    # Returns the arguments of the plugin
    # @return [Hash] a hash by argument key of argument values
    def args
      @_args
    end

    # Sets and propagates plugin arguments
    # @param [Hash <Symbol, Object>] args
    def args!(args)
      @_args.merge! args
      @plugins.each do |tag,plugin|
        plugin_args = args.key?(tag) ? args[tag] : {}
        shared_args = args.select { |t,a| not @plugins.keys.include? t }
        plugin.args! shared_args.merge! plugin_args
      end
    end

    def to_str(tag = default_plugin.tag)
      pd = perfdata(tag)
      if pd.empty?
        s_format = '%s: %s'
        s_array = [@plugins[tag].status,@plugins[tag].output]
      else
        s_format = '%s: %s | %s'
        s_array = [@plugins[tag].status,@plugins[tag].output,pd.join(' ').strip]
      end
      s_format % s_array
    end

    # Execute, evaluate and exit the plugin according to the plugin status, outputting the plugin's text output (and performance data, if applicable)
    # @param tag [Symbol] a plugin tag
    def exec!(tag = default_plugin.tag)
      t = Benchmark.realtime do
        exec tag
        eval tag
      end
      @plugins[tag].perfdata! "monitoring.#{File.basename($0)}.#{tag}", t if @plugins[tag].meta.benchmark
      exit tag
    end

    # Execute the plugin
    # @param tag [Symbol] a plugin tag
    def exec(t = default_plugin.tag)
      plugin = target_plugin t
      if plugin.has_plugins?
        plugin.plugins.each_value { |p| exec p }
      else
        plexec plugin
      end
    end

    def eval(tag = default_plugin.tag)
      @plugins[tag].eval
    end

    def eval!(tag = default_plugin.tag)
      @plugins[tag].eval
      exit tag
    end

    def eject!(payload = nil)
      o = case payload
            when String then payload
            when Exception then "#{payload.backtrace[1][/.+:\d+/]}: #{payload.message}"
            else nil
              caller[0][/.+:\d+/]
          end
      print "UNKNOWN: plugin eject! in %s\n" % [o]
      Kernel::exit 3
    end

    # @return [Array<PerformanceData>] a list of performance data objects
    def perfdata(tag = default_plugin.tag)
      @plugins[tag].perfdata(:deep).flatten.select { |pd| pd}
    end

    private

    def plexec(p)
      begin
        @_running = p.tag
        instance_exec p, &p.block
        @_running = nil
      rescue Naplug::Error => e
        p.status.unknown!
        p.output! "#{e.backtrace[1][/[^\/]+:\d+/]}: #{e.message}"
        p.payload! e
      rescue => e
        p.status.unknown!
        p.output!  "#{e.backtrace[0][/[^\/]+:\d+/]}: #{e.message}"
        p.payload! e
      ensure
        @_runinng = nil
      end
    end

    def plugins!
      self.class.plugins.each do |tag,plugin|
        @plugins[tag] = Plugin.new tag, plugin.block, plugin.meta.to_h.merge(:meta => false)
      end
    end

    def default_plugin
      return @plugins[:main] if @plugins.key? :main
      return @plugins[@plugins.keys[0]] if @plugins.size == 1
      raise Naplug::Error, 'unable to determine default plugin'
    end

    def target_plugin(target)
      case target
        when Symbol then @plugins[target]
        when Plugin then target
        else raise Naplug::Error, "unable to determine target plugin"
      end
    end

    def exit(tag = default_plugin.tag)
      benchmark = Time.now - self.class._time[:start]
      puts benchmark
      print "%s\n" % [to_str(tag)]
      Kernel::exit @plugins[tag].status.to_i
    end

    def method_missing(method, *args, &block)
      message = "undefined instance variable or method #{method}"
      case @_runinng
        when nil?
          begin; raise Naplug::Error, message; rescue => e; eject! e ; end
        else
          raise Naplug::Error, message
      end
    end

    def respond_to_missing?(method, *)
      @plugins.keys? method || super
    end

  end

  def self.included(klass)
    klass.send :include, InstanceMethods
    klass.extend ClassMethods
  end

end