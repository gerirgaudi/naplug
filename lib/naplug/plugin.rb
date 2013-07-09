require 'ostruct'
require 'logger'
require 'naplug/pluginmixin'

module Nagios

  class Plugin

    @plugins = {}
    @logger = Logger.new(STDERR)
    @logger.level = Logger::WARN
    class << self; attr_accessor :plugins, :logger end
    class DuplicatePlug < StandardError; end
    class UnknownPlug < StandardError; end

    def self.plugin(tag = nil,&block)
      tag = tag.nil? ? :main : tag.to_sym
      raise DuplicatePlug, "duplicate definition of #{tag} plugin" if self.plugins.has_key?(tag)
      self.plugins[tag] = Plug.new tag, block
    end

    def self.inherited(subclass)
      subclass.plugins = {}
      subclass.logger = self.logger
    end

    include PluginMixin

    attr_reader :plugins, :logger

    def initialize(args = {}, options = {})
      @plugins = self.class.plugins
      @logger = options[:log].nil? ? self.class.logger : options[:log]
      @status = Status.new :unknown
      @output = 'uninitialized plugin'
      @payload = nil
      @args = args
      process_args(args)
    end

    def exec
      @plugins.each_value do |plug|
        @logger.debug "exec #{plug.tag}"
        instance_exec plug, &plug.block
      end
    end

    def eval
      status = Status.new :ok
      output = ''

      @plugins.each_value do |plug|
        if plug.status > status
          output = plug.output
          status = plug.status
        elsif plug.status == status
          output << "; #{plug.output}" unless plug.output.nil?
        end
      end

      @status = status
      @output = output
    end

    def exec!
      exec
      eval
      print "%s\n" % [single_line_output]
      exit exit_code
    end

    def status(t = nil)
      t.nil? ? @status : @plugins[tag(t)].status
    end

    def output(t = nil)
      t.nil? ? @status : @plugins[tag(t)].output
    end

    def payload(t = nil)
      t.nil? ? @status : @plugins[tag(t)].payload
    end

    def single_line_output(t = nil)
      '%s: %s' % [@status.to_s,@output]
    end

    def exit_code(t = nil)
      @status.to_i
    end

    def tags
      @plugins.keys
    end

    def plugin(t)
      raise UnknownPlug, "unknown plug #{tag(t)}" unless tags.include?(tag(t))
      @plugins[tag(t)]
    end

    private

    def tag(t)
      t.nil? ? :main : t.to_sym
    end

    def process_args(args,mode = nil)
      @plugins.each do |t,p|
        p.args = args.select { |k,v| @plugins[k].nil? }
        p.args.merge!(args[t]) unless args[t].nil?
      end
    end

end end