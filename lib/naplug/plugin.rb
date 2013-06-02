require 'ostruct'
require 'naplug/pluginmixin'

module Nagios

  class Plugin

    @plugins = {}
    class << self; attr_accessor :plugins end
    class DuplicateTag < StandardError; end
    class UnknownPlugin < StandardError; end

    def self.plugin(tag = nil,*args,&block)
      tag = tag.nil? ? :main : tag.to_sym
      raise DuplicateTag, "duplicate definition of #{tag} plugin" if self.plugins.has_key?(tag)
      self.plugins[tag] = OpenStruct.new :args => {}, :block => block, :result => Result.new
    end

    def self.inherited(subclass)
      subclass.plugins = {}
    end

    include PluginMixin

    attr_reader :result, :plugins

    def initialize(args = {})
      @plugins = self.class.plugins
      @result = {}
      process_args(args)
    end

    def exec
      @plugins.each_pair do |tag,plugin|
        @result[tag] = instance_exec plugin.args, &plugin.block
      end
    end

    def eval
      true
    end

    def exec!
      exec
      print "%s\n" % [single_line_output]
      exit exit_code
    end

    def status(t = nil)
      @result[tag(t)].status
    end

    def output(t = nil)
      @result[tag(t)].output
    end

    def single_line_output(t = nil)
      '<single_line_output>'
#      '%s: %s' % [@result[tag(t)].status.to_s,@result[tag(t)].output]
    end

    def exit_code(t = nil)
      @result[tag(t)].status.to_i
    end

    def payload(t = nil)
      @result[tag(t)].payload
    end

    def tags
      @plugins.keys
    end

    def plugin(t)
      raise UnknownPlugin, "unknown plugin #{tag(t)}" unless tags.include?(tag(t))
      @plugin[tag(t)]
    end

    private

    def tag(t)
      t.nil? ? :main : t.to_sym
    end

    def process_args(args)
      puts "ARGS: #{args}"
      @plugins.each do |t,p|
        puts "tag: #{t}: #{p}"
        p.args = args.select { |k,v| @plugins[k].nil? }
        p.args.merge!(args[t]) unless args[t].nil?
      end
    end

end end