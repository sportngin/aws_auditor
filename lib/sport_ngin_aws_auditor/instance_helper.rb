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
        instance_hash[key] = [instance_hash[key]]
      end
      instance_hash
    end

    def add_instances_with_tag_to_hash(instances_to_add, instance_hash)
      puts "hello"
      instances_to_add.each do |instance|
        next if instance.nil?
        key = instance.to_s.dup << " with tag"
        instance_result = []
        
        if instance_hash.has_key?(instance.to_s) && instance_hash[instance.to_s][0] > 0
          current_val = instance_hash[instance.to_s][0]
          val = current_val - instance.count
          new_val = val >= 0 ? val : 0
          instance_hash[instance.to_s][0] = new_val

          val = instance.count - current_val
          new_val = val >= 0 ? val : 0
          instance_result << new_val
        else
          if instance_hash.has_key?(key)
            instance_result << instance_hash[key][0] + instance.count
          else
            instance_result << instance.count
          end
        end

        instance_result << instance.name
        instance_result << instance.tag_reason
        instance_result << instance.tag_value
        instance_hash[key] = instance_result
      end if instances_to_add
      instance_hash
    end

    def compare(instances)
      differences = Hash.new()
      instances_with_tag = filter_instances_with_tags(instances)
      instances_without_tag = filter_instance_without_tags(instances)
      instance_hash = instance_count_hash(instances_without_tag)
      ris = instance_count_hash(get_reserved_instances)
      
      instance_hash.keys.concat(ris.keys).uniq.each do |key|
        instance_count = instance_hash.has_key?(key) ? instance_hash[key][0] : 0
        ris_count = ris.has_key?(key) ? ris[key][0] : 0
        differences[key] = [ris_count - instance_count]
      end
      
      add_instances_with_tag_to_hash(instances_with_tag, differences)
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
    def filter_instance_without_tags(instances)
      instances.select do |instance|
        value = gather_instance_tag_date(instance)
        value.nil? || (Date.today.to_s >= value.to_s)
      end
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
