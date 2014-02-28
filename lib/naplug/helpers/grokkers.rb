module Naplug

  module Helpers

    module Grokkers

      def tagmeta_grok(tagmeta)
        case tagmeta.size
          when 0
            [:main, {}]
          when 1
            case tagmeta[0]
              when Symbol
                [tagmeta[0], {}]
              when Hash
                [:main,tagmeta[0]]
              else
                raise Naplug::Error, 'ArgumentError on Naplug#plugin'
            end
          when 2
            raise Naplug::Error, 'ArgumentError on Naplug#plugin' unless tagmeta[0].is_a? Symbol and tagmeta[1].is_a? Hash
            tagmeta[0..1]
          else
            raise Naplug::Error, 'ArgumentError on Naplug#plugin'
        end
      end
    end
  end
end
