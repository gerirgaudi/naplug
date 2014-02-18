require 'naplug/status'

module Naplug

  class Plugin

    attr_reader :name, :block, :plugs, :tag

    class DuplicatePlugin < StandardError; end
    class UnknownPlugin < StandardError; end

    def initialize(tag, klass, block)
      @tag = tag
      @klass = klass
      @block = block
      @plugs = Hash.new

      @_args = {}
      @_status = Status.new
      @_output = ''
      @_payload = nil

      begin
        instance_eval &block if block
      rescue => e
        # do nothing
      end

      @_status.unknown!
      @_output = 'uninitialized plugin'

    end

    def plug(tag, &block)
      raise DuplicatePlugin, "duplicate definition of #{tag}" if @plugs.key? tag
      @plugs[tag] = Plugin.new tag, @klass, block
      self.define_singleton_method tag do
        @plugs[tag]
      end
    end

    def status
      @_status
    end

    def output
      @_output
    end

    def output!(o)
      @_output = o
    end

    def payload
      @_payload
    end

    def payload!(p)
      @_payload = p
    end

    def args
      @_args
    end

    def args!(a)
      @_args = a
      process_arguments(a)
    end

    def [](k)
      @_args[k]
    end

    def []=(k,v)
      @_args[k] = v
    end

    def exec!(*args)
      exec
      eval
      print "%s\n" % [to_s]
      exit @_status.to_i
    end

    def to_s
      '%s: %s' % [status,output]
    end

    def exec
      begin
        if @plugs.empty?
          instance_eval &@block
        else
          @plugs.each_value do |plug|
            instance_exec plug, &plug.block
          end
        end
      rescue => e         # catch any and all exceptions: plugins are a very restrictive environment
        status.unknown!
        output! e.message
        payload! e
      end

    end

    def eval
      unless @plugs.empty?
        wcu_plugs = @plugs.values.select { |plug| plug.status.not_ok? }
        plugs = wcu_plugs.empty? ? @plugs : wcu_plugs
        @_output = plugs.map { |plug| "[#{plug.tag}@#{plug.status.to_l}: #{plug.output}]" }.join(' ')
        @_status = plugs.map { |plug| plug.status }.max
      end
    end

    def process_arguments(args)
      @plugs.each do |tag,plug|
        plug_args = args.key?(tag) ? args[tag] : {}
        shared_args = args.select { |t,a| not @plugs.keys.include? t }
        plug.args! shared_args.merge! plug_args
      end
    end

    def method_missing(method,*args,&block)
      puts @klass
      @klass.send method
      puts method
      exit 0
    end

  end
end
