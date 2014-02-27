require 'json'

module Naplug

  module Helpers

    module JSON_Thresholds

      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods
        def hashify_json_thresholds(*threstag)
          tag, thresholds_json, thresholds_hash = case threstag.size
                                                    when 0, 1
                                                     [nil, threstag[0], {}]
                                                    else
                                                     [threstag[1],threstag[0], {}]
                                                  end
          plug = nil
          thresholds_proc = Proc.new do |json_element|
            case
              when (json_element.is_a? String and json_element.match(/\d*:\d*:\d*:\d*/))
                case tag.nil?
                  when true
                    thresholds_hash[plug] = Hash[Status.states.zip json_element.split(':',-1).map { |v| v.nil? ? nil : v.to_i } ]
                  else
                    thresholds_hash[tag] = Hash[plug, Hash[Status.states.zip json_element.split(':',-1).map { |v| v.nil? ? nil : v.to_i } ]]
                end
              when Symbol
                plug = json_element
              else
                nil
            end
          end
          JSON.recurse_proc(JSON.parse(thresholds_json, :symbolize_names => true),&thresholds_proc) if thresholds_json
          thresholds_hash
        end
      end

    end

  end

end
