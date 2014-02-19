require 'rubygems'
require 'awesome_print'

require 'naplug/plugin'

module Naplug

  module ClassMethods

    attr_reader :plugins

    class DuplicatePlugin < StandardError; end
    class UnknownPlugin < StandardError; end
    class OnlyOnePlugin < StandardError; end

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
          self.class.plugins[tag]
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

    attr_reader :args

    def initialize(args = {})
      args! args
    end

    def args
      @_args
    end

    def args!(a)
      @_args = a
      process_arguments(a)
    end

    def to_s(tag = default_plugin.tag)
      '%s: %s' % [plugins[tag].status,plugins[tag].output]
    end

    def plugins
      self.class.plugins
    end

    def exec!(tag = default_plugin.tag)
      exec tag
      eval tag
      exit tag
    end

    def exec(tag = default_plugin.tag)
      plugin = plugins[tag]
      begin
        if plugin.has_plugs?
          plugin.plugs.each_value { |plug| instance_exec plug, &plug.block }
        else
          instance_exec plugin, &plugin.block
        end
      rescue => e         # catch any and all exceptions: plugins are a very restrictive environment
        plugin.status.unknown!
        plugin.output! e.message
        plugin.payload! e
      end
    end

    def eval(tag = default_plugin.tag)
      plugins[tag].eval
    end

    private

    def process_arguments(args)
      self.class.plugins.each do |tag,plugin|
        plugin_args = args.key?(tag) ? args[tag] : {}
        shared_args = args.select { |t,a| not self.class.plugins.keys.include? t }
        plugin.args! shared_args.merge! plugin_args
      end
    end

    def default_plugin
      return plugins[:main] if plugins.key? :main
      return plugins[plugins.keys[0]] if plugins.size == 1
      nil
    end

    def method_missing(method, *args, &block)
      plugin = Plugin.new method, block
      plugin.output! "undefined plugin #{method.to_s.chomp('!')}"
      print "%s\n" % [plugin]
      Kernel::exit plugin.status.to_i
    end

    def exit(tag = default_plugin.tag)
      print "%s\n" % [to_s(tag)]
      Kernel::exit plugins[tag].status.to_i
    end

  end

  def self.included(klass)
    klass.send :include, InstanceMethods
    klass.extend ClassMethods
  end

end