require 'trollop'
require 'naplug'

module Naplug

  module Helpers

    module CLI

      def self.included(klass)
        klass.send :include, InstanceMethods
        klass.extend ClassMethods
      end

      module ClassMethods
        include Trollop

        def with_standard_exception_handling parser
          begin
            yield
          rescue CommandlineError => e
            plugin = Naplug::Plugin.new :cli, nil
            plugin.output! e.message
            print "%s: %s\n" % [plugin.status.to_s,plugin.output]
            exit plugin.status.to_i
          rescue HelpNeeded
            parser.educate
            exit
          rescue VersionNeeded
            puts parser.version
            exit
          end
        end
      end

      module InstanceMethods
        def initialize
        end
      end

    end

  end
end