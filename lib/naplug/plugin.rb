require 'ostruct'
require 'naplug/pluginmixin'

module Nagios

  class Plugin

    @plugins = {}
    class << self; attr_accessor :plugins end
    class DuplicateTag < StandardError; end

    def self.plugin(tag = nil,*args,&block)
      tag = tag.nil? ? :main : tag.to_sym
      raise DuplicateTag, "duplicate definition of #{tag} plugin" if self.plugins.has_key?(tag)
      self.plugins[tag] = block
    end

    def self.inherited(subclass)
      subclass.plugins = {}
    end


    include PluginMixin

    def initialize(args = {})
      @args = args
      @result = {}
    end

    def exec
      self.class.plugins.each_pair do |tag,plugin|
        @result[tag] = instance_exec @args, &plugin
      end
    end

    def exec!
      exec
      puts single_line_output
      exit exit_code
    end

    def status(t = nil)
      @result[tag(t)].status
    end

    def output(t = nil)
      @result[tag(t)].output
    end

    def single_line_output(t = nil)
      '%s: %s' % [@result[tag(t)].status.to_s,@result[tag(t)].output]
    end

    def exit_code(t = nil)
      @result[tag(t)].status.to_i
    end

    def payload(t = nil)
      @result[tag(t)].payload
    end

    def tags
      self.class.plugins.keys
    end

    private

    def tag(t)
      t.nil? ? :main : t.to_sym
    end

end end