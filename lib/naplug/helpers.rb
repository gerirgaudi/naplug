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

  end

end