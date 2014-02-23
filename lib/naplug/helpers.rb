require 'json'
require 'naplug/status'

module Naplug

  module Helpers

    module Thresholds

      def hashify_json_thresholds(tag,thres_json=nil)
        thresholds = { tag => {} }
        plug = nil
        thres_proc = Proc.new do |json_element|
          case
            when (json_element.is_a? String and json_element.match(/\d*:\d*:\d*:\d*/))
              thresholds[:main][plug] = Hash[Status.states.zip json_element.split(':',-1).map { |v| v.nil? ? nil : v.to_i } ]
            when Symbol
              plug = json_element
            else
              nil
          end
        end
        JSON.recurse_proc(JSON.parse(thres_json, :symbolize_names => true),&thres_proc) if thres_json
        thresholds
      end

    end

    module Hashes

      # Thx Avdi Grimm! http://devblog.avdi.org/2009/11/20/hash-transforms-in-ruby/
      def transform_hash(original, options={}, &block)
        original.inject({}){|result, (key,value)|
          value = if options[:deep] && Hash === value
                    transform_hash(value, options, &block)
                  else
                    value
                  end
          block.call(result,key,value)
          result
        }
      end

      def symbolify_keys(hash)
        transform_hash(hash) {|h, key, value|
          h[key.to_sym] = value
        }
      end


    end

  end

end