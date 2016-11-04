require_relative './recently_retired_tag'
require_relative './audit_data'

module SportNginAwsAuditor
  module InstanceHelper

    def instance_hash
      Hash[get_instances.map { |instance| instance.nil? ? next : [instance.id, instance]}.compact]
    end

    def reserved_instance_hash
      Hash[get_reserved_instances.map { |instance| instance.nil? ? next : [instance.id, instance]}.compact]
    end

    def instance_count_hash(instances)
      instance_hash = Hash.new()
      instances.each do |instance|
        next if instance.nil?
        instance_hash[instance.to_s] = instance_hash.has_key?(instance.to_s) ? instance_hash[instance.to_s] + instance.count : instance.count
      end if instances

      instance_hash.each do |key, value|
        instance_hash[key] = {:count => instance_hash[key], :region_based => false}
      end
      instance_hash
    end

    def apply_tagged_instances(instances_to_add, instance_hash)
      instances_to_add.each do |instance|
        next if instance.nil?
        key = instance.to_s.dup << " with tag (" << instance.name << ")"
        instance_result = {}
        
        if instance_hash.has_key?(instance.to_s) && instance_hash[instance.to_s][:count] > 0
          current_val = instance_hash[instance.to_s][:count]
          val = current_val - instance.count
          new_val = val >= 0 ? val : 0
          instance_hash[instance.to_s][:count] = new_val

          val = instance.count - current_val
          new_val = val >= 0 ? val : 0
          instance_result[:count] = new_val
        else
          instance_result[:count] = instance.count
        end

        instance_result.merge!({:name => instance.name, :tag_reason => instance.tag_reason,
                                :tag_value => instance.tag_value, :region_based => false})
        instance_hash[key] = instance_result
      end if instances_to_add
      instance_hash
    end

    def apply_region_ris(ris_region, differences)
      ris_region.each do |ri|
        differences.each do |key, value|
          # if key = 'Linux VPC us-east-1a t2.medium'...
          my_match = key.match(/(\w*\s*\w*\s*)\w{2}-\w{2,}-\w{2}(\s*\S*)/)

          # then platform = 'Linux VPC'...
          platform = my_match[1] if my_match
          platform[platform.length - 1] = ''

          # and size = 't2.medium'
          size = my_match[2] if my_match
          size[0] = ''

          if (platform == ri.platform) && (size == ri.instance_type) && (value[:count] < 0)
            until (ri.count == 0) || (value[:count] == 0)
              value[:count] = value[:count] + 1
              ri.count = ri.count - 1
            end
          end
        end
      end

      ris_region.each do |ri|
        differences[ri.to_s] = {:count => ri.count, :region_based => true}
      end
    end

    def measure_differences(instance_hash, ris_hash)
      differences = Hash.new()
      instance_hash.keys.concat(ris_hash.keys).uniq.each do |key|
        instance_count = instance_hash.has_key?(key) ? instance_hash[key][:count] : 0
        ris_count = ris_hash.has_key?(key) ? ris_hash[key][:count] : 0
        differences[key] = {:count => ris_count - instance_count, :region_based => false}
      end
      differences
    end

    def compare(instances)
      instances_with_tag = filter_instances_with_tags(instances)
      instances_without_tag = filter_instances_without_tags(instances)
      instance_hash = instance_count_hash(instances_without_tag)

      ris = get_reserved_instances
      ris_availability = filter_ris_availability_zone(ris)
      ris_region = filter_ris_region_based(ris)
      ris_hash = instance_count_hash(ris_availability)
      
      differences = measure_differences(instance_hash, ris_hash)
      apply_region_ris(ris_region, differences)
      apply_tagged_instances(instances_with_tag, differences)
      differences
    end

    # this gets all retired reserved instances and filters out only the ones that have expired
    # within the past week
    def get_recent_retired_reserved_instances
      get_retired_reserved_instances.select do |ri|
        ri.expiration_date > (Time.now - 604800)
      end
    end

    # assuming the value of the tag is in the form: 01/01/2000 like a date
    def filter_instances_with_tags(instances)
      instances.select do |instance|
        value = gather_instance_tag_date(instance)
        value && (Date.today.to_s < value.to_s)
      end
    end

    # assuming the value of the tag is in the form: 01/01/2000 like a date
    def filter_instances_without_tags(instances)
      instances.select do |instance|
        value = gather_instance_tag_date(instance)
        value.nil? || (Date.today.to_s >= value.to_s)
      end
    end

    # this gathers all RIs except the region-based RIs
    def filter_ris_availability_zone(ris)
      ris.reject { |ri| ri.scope == 'Region' }
    end

    # this filters all of the region-based RIs
    def filter_ris_region_based(ris)
      ris.select { |ri| ri.scope == 'Region' }
    end

    # this returns a hash of all instances that have retired between 1 week ago and today
    def get_retired_tags(instances)
      return_array = []
      
      instances.select do |instance|
        value = gather_instance_tag_date(instance)
        one_week_ago = (Date.today - 7).to_s
        if (value && (one_week_ago < value.to_s) && (value.to_s < Date.today.to_s))
          return_array << RecentlyRetiredTag.new(value.to_s, instance.to_s, instance.name, instance.tag_reason)
        end
      end
      
      return_array
    end

    def gather_instance_tag_date(instance)
      value = instance.no_reserved_instance_tag_value
      unless value.nil?
        date_hash = Date._strptime(value, '%m/%d/%Y')
        value = Date.new(date_hash[:year], date_hash[:mon], date_hash[:mday]) if date_hash
      end
      value
    end
  end
end
