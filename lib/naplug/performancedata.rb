module Naplug

  class PerformanceData

    attr_reader :tag, :data

    class MissingLabel < StandardError; end
    class InvalidField < StandardError; end
    class ThatIsNoHash < StandardError; end

    FIELDS = [:label, :value, :uom, :warn, :crit, :min, :max] # label=value[UOM];[warn];[crit];[min];[max]

    def initialize(tag)
      @tag = tag
      @data = Hash.new
    end

    def to_s(label = nil)
      label_ary = label.nil? ? @data.keys : [label]
      label_ary.map do |l|
        '%s=%s%s;%s;%s;%s;%s' % FIELDS.map { |k| @data[l][k] }
      end.join(' ').strip
    end

    def []=(label,value,args = {})
      raise ThatIsNoHash, 'hash of fields is not a hash' unless args.is_a? Hash
      args.keys.each { |field| raise InvalidField unless FIELDS.include? field }
      raise MissingLabel, 'missing label' unless label
      @data[label] = { :label => label, :value => value }.merge args
    end
    alias_method :store, :[]=

    def [](label)
      @data[label]
    end
    alias_method :fetch, :[]

    def delete(label)
      @data.delete(label)
    end

    def has_label?(label)
      @data.has_key? label
    end
    alias_method :include?, :has_label?

    def fields
      FIELDS
    end

  end
end