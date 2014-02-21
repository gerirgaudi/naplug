require 'rubygems'
require 'naplug/plugin'

module Naplug

  module ClassMethods

    attr_reader :plugins

    class DuplicatePlugin < StandardError; end
    class UnknownPlugin < StandardError; end

    def plugin(tag = :main, &block)
      @plugins = Hash.new unless @plugins
      raise DuplicatePlugin, "duplicate definition of #{tag}" if @plugins.key? tag
      @plugins[tag] = create_plugin tag, block
    end

    private

    def create_plugin(tag,block)
      plugin = Plugin.new tag, block

      module_eval do
        # setup <tag> methods for quick access to plugins
        define_method "#{tag}".to_sym do
          @plugins[tag]
        end
        # setup <tag>! methods to involke exec! on a given plugin; it is desitable for this to accept arguments (future feature?)
        define_method "#{tag}!".to_sym do
          self.exec! tag
        end
      end
      plugin
    end

  end

  module InstanceMethods

    attr_reader :plugins

    def initialize(args = {})
      @plugins = Hash.new
      plugins!

      @_args = Hash.new
      args! args
    end

    def args
      @_args
    end

    def args!(args)
      @_args.merge! args
      @plugins.each do |tag,plugin|
        plugin_args = args.key?(tag) ? args[tag] : {}
        shared_args = args.select { |t,a| not @plugins.keys.include? t }
        plugin.args! shared_args.merge! plugin_args
      end
    end

    def to_s(tag = default_plugin.tag)
      '%s: %s | %s' % [@plugins[tag].status,@plugins[tag].output,perfdata(tag).strip]
    end

    def exec!(tag = default_plugin.tag)
      exec tag
      eval tag
      exit tag
    end

    def exec(tag = default_plugin.tag)
      plugin = @plugins[tag]
      if plugin.has_plugs?
        plugin.plugs.each_value do |plug|
          begin
            instance_exec plug, &plug.block
          rescue => e
            plug.status.unknown!
            plug.output! e.message
            plug.payload! e
          end
        end
      else
        begin
          instance_exec plugin, &plugin.block
        rescue => e
          plugin.status.unknown!
          plugin.output! e.message
          plugin.payload! e
        end
      end
    end

    def eval(tag = default_plugin.tag)
      @plugins[tag].eval
    end

    private

    def plugins!
      self.class.plugins.each do |tag,plugin|
        @plugins[tag] = Plugin.new tag, plugin.block
      end
    end

    def default_plugin
      return @plugins[:main] if @plugins.key? :main
      return @plugins[@plugins.keys[0]] if @plugins.size == 1
      nil
    end

    def perfdata(tag = default_plugin.tag)
      plugin = @plugins[tag]
      if plugin.has_plugs?
        plugin.plugs.values.map do |plug|
          plug.perfdata
        end.join(' ')
      else
        plugin.perfdata
      end
    end

    def method_missing(method, *args, &block)
      plugin = Plugin.new method, block
      plugin.output! "undefined plugin #{method.to_s.chomp('!')}"
      print "%s\n" % [plugin]
      Kernel::exit plugin.status.to_i
    end

    def exit(tag = default_plugin.tag)
      print "%s\n" % [to_s(tag)]
      Kernel::exit @plugins[tag].status.to_i
    end

  end

  def self.included(klass)
    klass.send :include, InstanceMethods
    klass.extend ClassMethods
  end

end