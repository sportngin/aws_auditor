module SportNginAwsAuditor
  class EC2Instance
    extend InstanceHelper

    class << self
      def get_instances(client=AWS.ec2, tag_name=nil)
        instances = client.describe_instances.reservations.map do |reservation|
          reservation.instances.map do |instance|
            next unless instance.state.name == 'running'
            new(instance, tag_name)
          end.compact
        end.flatten.compact
        get_more_info(instances, client)
      end

      def get_reserved_instances(client=AWS.ec2)
        client.describe_reserved_instances.reserved_instances.map do |instance|
          next unless instance.state == 'active'
          new(instance, nil, instance.instance_count)
        end.compact
      end

      def get_retired_reserved_instances(client)
        client.describe_reserved_instances.reserved_instances.map do |instance|
          next unless instance.state == 'retired'
          new(instance, nil, instance.instance_count)
        end.compact
      end

      def bucketize(client)
        buckets = {}
        get_instances(client).map do |instance|
          name = instance.stack_name || instance.name
          if name
            buckets[name] = [] unless buckets.has_key? name
            buckets[name] << instance
          else
            puts "Could not sort #{instance.id}, as it has no stack_name or name"
          end
        end
        buckets.sort_by{|k,v| k }
      end

      def get_more_info(instances, client)
        instances.each do |instance|
          tags = client.describe_tags(:filters => [{:name => "resource-id", :values => [instance.id]}]).tags
          tags = Hash[tags.map { |tag| [tag[:key], tag[:value]]}.compact]
          instance.name = tags["Name"]
          instance.stack_name = tags["opsworks:stack"]
        end
      end
      private :get_more_info
    end

    attr_accessor :id, :name, :platform, :availability_zone, :scope, :instance_type, :count, :stack_name,
                  :tag_value, :tag_reason, :expiration_date, :count_remaining
    def initialize(ec2_instance, tag_name, count=1)
      if ec2_instance.class.to_s == "Aws::EC2::Types::ReservedInstances"
        self.id = ec2_instance.reserved_instances_id
        self.name = nil
        self.platform = platform_helper(ec2_instance.product_description)
        self.scope = ec2_instance.scope
        self.availability_zone = self.scope == 'Region' ? nil : ec2_instance.availability_zone
        self.availability_zone << ' ' if self.availability_zone != nil
        self.instance_type = ec2_instance.instance_type
        self.count = count
        self.stack_name = nil
        self.expiration_date = ec2_instance.end if ec2_instance.state == 'retired'
      elsif ec2_instance.class.to_s == "Aws::EC2::Types::Instance"
        self.id = ec2_instance.instance_id
        self.name = ec2_instance.key_name
        self.platform = platform_helper((ec2_instance.platform || ''), ec2_instance.vpc_id)
        self.scope = nil
        self.availability_zone = ec2_instance.placement.availability_zone
        self.availability_zone << ' ' if self.availability_zone != nil
        self.instance_type = ec2_instance.instance_type
        self.count = count
        self.stack_name = nil

        # go through to see if the tag we're looking for is one of them
        if tag_name
          ec2_instance.tags.each do |tag|
            if tag.key == tag_name
              self.tag_value = tag.value
            elsif tag.key == 'no-reserved-instance-reason'
              self.tag_reason = tag.value
            end
          end
        end
      end
    end

    def to_s
      "#{platform} #{availability_zone}#{instance_type}"
    end

    def no_reserved_instance_tag_value
      @tag_value
    end

    def platform_helper(description, vpc=nil)
      platform = ''

      if description.downcase.include?('windows')
        platform << 'Windows'
      elsif description.downcase.include?('linux') || description.empty?
        platform << 'Linux'
      end

      if ec2_classic_support && (description.downcase.include?('vpc') || vpc)
        platform << ' VPC'
      end

      return platform
    end
    private :platform_helper

    def ec2_classic_support(client=AWS.ec2)
      account_attributes = client.describe_account_attributes.account_attributes
      attribute = account_attributes.select { |aa| aa.attribute_name == 'supported-platforms' }.first
      attribute_values = attribute.attribute_values
      attribute_values_array = attribute_values.collect { |v| v.attribute_value }
      return attribute_values_array.include?('EC2')
    end
  end
end
