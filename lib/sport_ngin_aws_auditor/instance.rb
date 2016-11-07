require_relative './instance_helper'

module SportNginAwsAuditor
  class Instance
    extend InstanceHelper

    attr_accessor :type, :count, :category, :tag_value, :reason, :name, :region_based
    def initialize(type, data_hash, region)
      if type.include?(" with tag")
        type = type.dup # because type is a frozen string right now
        type.slice!(" with tag")
        self.type = type
        self.category = "tagged"
        self.name = data_hash[:name] || nil
        self.reason = data_hash[:tag_reason] || nil
        self.tag_value = data_hash[:tag_value] || nil
        self.region_based = data_hash[:region_based] || nil
      else
        self.region_based = data_hash[:region_based] || nil

        if data_hash[:count] < 0
          self.category = "running"
        elsif data_hash[:count] == 0
          self.category = "matched"
        elsif data_hash[:count] > 0
          self.category = "reserved"
        end

        if region_based?
          # if type = 'Linux VPC  t2.small'...
          my_match = type.match(/(\w*\s*\w*\s{1})\s*(\s*\S*)/)

          # then platform = 'Linux VPC '...
          platform = my_match[1] if my_match

          # and size = 't2.small'
          size = my_match[2] if my_match

          self.type = platform << region << ' ' << size
        else
          self.type = type
        end
      end

      self.count = data_hash[:count].abs
    end

    def region_based?
      self.region_based
    end

    def tagged?
      self.category == "tagged"
    end

    def reserved?
      self.category == "reserved"
    end

    def running?
      self.category == "running"
    end

    def matched?
      self.category == "matched"
    end
  end
end
