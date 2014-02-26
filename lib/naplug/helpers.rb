require 'json'
require 'timeout'
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

    module ENGraphite

      class Client

        attr_reader :metrics

        def initialize(options)
          raise ArgumentError, 'missing graphite server address' if options[:graphite].nil?
          @graphite = options[:graphite]
          @port = options[:port].nil? ? 2003 : options[:port].to_i
          @prefix = options[:prefix].nil? ? '' : options[:prefix]
          @metrics = []
        end

        def metric path, value, time = Time.now
          @metrics.push(Metric.new(path,value,time))
        end

        def metrics!
          @metrics.each do |metric|
            metric = "#{@prefix}.#{metric.to_s}\n"
            print metric
          end
        end

        def flush!(options = { :timeout => 3})
          begin
            Timeout.timeout(options[:timeout]) do
              sleep 5
              s = TCPSocket.open(@graphite,@port)
              @metrics.each do |metric|
                metric = "#{@prefix}.#{metric.to_s}\n"
                s.write metric
              end
              s.close
            end
          rescue Timeout::Error => e
            raise Naplug::Error, "graphite timeout (#{options[:timeout]}s)"
          rescue Errno::ECONNREFUSED => e
            raise Naplug::Error, 'graphite connection refused'
          end
        end
      end

      class Metric

        attr_reader :path, :value, :time

        def initialize(path,value,time = Time.now)
          @path = path
          @value = value
          @time = time
        end

        def to_s
          '%s %d %d' % [@path,@value,@time.to_i]
        end
      end

    end

  end

end