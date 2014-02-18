require 'rubygems'

require 'naplug/plugin'

module Naplug

  module ClassMethods

    attr_reader :plugins

    def plugin(tag = :main, &block)
      puts self
      @plugins = Hash.new unless @plugins
      @plugins[tag] = create_plugin tag, block
    end

    private

    def create_plugin(tag,block)
      plugin = Plugin.new tag, self, block

      module_eval do
        # setup <tag> methods for quick access to plugins
        define_method "#{tag}".to_sym do
          self.class.plugins[tag]
        end
        # setup <tag>! methods to involke exec! on a given plugin; it is desitable for this to accept arguments (future feature?)
        define_method "#{tag}!".to_sym do |*args|
          a = args.empty? ? {} : args
          self.class.plugins[tag].send 'exec!'.to_sym, a
        end
      end
      plugin
    end

  end

  module InstanceMethods

    attr_reader :args

    def initialize(args = {})
      @args = args
      self.class.plugins.each do |tag,plugin|
        plugin_args = args.key?(tag) ? args[tag] : {}
        shared_args = args.select { |t,a| not self.class.plugins.keys.include? t }
        plugin.args! shared_args.merge! plugin_args
      end
    end

    def plugins
      self.class.plugins
    end

    def method_missing(method, *args, &block)
      if self.class.plugins[:main].respond_to? method
        self.class.plugins[:main].send method, args unless args.empty?
        self.class.plugins[:main].send method if args.empty?
      end
    end

  end

  def self.included(klass)
    klass.send :include, InstanceMethods
    klass.extend ClassMethods
  end

end