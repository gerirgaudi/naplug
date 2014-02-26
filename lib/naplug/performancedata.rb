require 'ostruct'

module Naplug

  class PerformanceData

    include Enumerable

    attr_reader :tag, :data, :meta

    FIELDS = [:label, :value, :uom, :warn, :crit, :min, :max]

    def initialize(plugin)
      @tag = plugin.tag
      @data = Hash.new
      @meta = OpenStruct.new :plugin => plugin, :ancestors => traverse_to_root(plugin)
    end

    # performance data format: 'label=value[UOM];[warn];[crit];[min];[max]'
    def to_str(label = nil)
      label_ary = label.nil? ? labels : [curate_label(label)]
      label_ary.map do |l|
        '%s=%s%s;%s;%s;%s;%s' % FIELDS.map { |k| @data[l][k] }
      end.join(' ').strip
    end

    # List of performance data label entries
    # @return [Array<Hash<label,field_data>>] an array of hashes keyed by field
    def to_a
      @data.values
    end

    # @raise Naplug::Error if the label contains invalid characters, the value is not a number, or specify invalid fields
    def []=(label,valuefields)
      value, fields = valuefields
      if validate_label label and validate_value value and validate_fields fields
        @data[curate_label(label)] = { :label => curate_label(label), :value => value }.merge fields
      else
        raise Naplug::Error, "invalid performance data label (#{label}), value (#{value}), field representation (#{fields.class}) or field (#{fields.keys.join(',')})"
      end
    end

    def each(&block)
      @data.values.each(&block)
    end

    def [](label)
      @data[curate_label(label)]
    end

    def delete(label)
      @data.delete(curate_label(label))
    end

    def include?(label)
      @data.has_key? curate_label(label)
    end
    alias_method :has_label?, :include?

    def keys
      @data.keys
    end
    alias_method :labels, :keys

    def fields
      FIELDS
    end

    # @return [Plugin] plugin performance data belongs to
    def plugin
      @meta.plugin
    end

    # @return [Array<Plugin>] of parent plugins
    def ancestors(options = { :mode => :tags, :separator => :/ })
      options[:separator] = :/ if options[:separator].nil?
      options[:mode].nil? ? @meta.ancestors : @meta.ancestors.map { |a| a.tag }.join(options[:separator].to_s)
    end

    private

    # can contain any characters except the equals sign or single quote (')
    def validate_label(l)
      l.nil? or l.to_s.index(/['=]/) ? false : true
    end

    def validate_value(v)
      true #      v =~ /^[0-9.-]+$/ ? true : false
    end

    def validate_fields(fields)
      fields.is_a? Hash and fields.keys.select { |field| not FIELDS.include? field }.empty? ? true : false
    end

    # single quotes for the label are optional; required if spaces are in the label
    def curate_label(l)
      l.to_s.index(/\s+/) ? "'#{l}'" : l.to_s
    end

    def traverse_to_root(plugin)
      lineage = []
      loop do
        break unless plugin.is_a? Plugin
        lineage.push plugin
        plugin = plugin.parent
      end
      lineage.reverse
    end

  end
end