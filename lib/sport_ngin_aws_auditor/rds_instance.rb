require_relative './instance_helper'

module SportNginAwsAuditor
  class RDSInstance
    extend InstanceHelper
    extend RDSWrapper
    extend AWSWrapper

    class << self
      attr_accessor :instances, :reserved_instances, :retired_reserved_instances

      def get_instances(tag_name=nil)
        return @instances if @instances
        account_id = get_account_id
        @instances = rds.describe_db_instances.db_instances.map do |instance|
          next unless instance.db_instance_status.to_s == 'available'
          new(instance, account_id, tag_name, rds)
        end.compact
      end

      def get_reserved_instances
        return @reserved_instances if @reserved_instances
        @reserved_instances = rds.describe_reserved_db_instances.reserved_db_instances.map do |instance|
          next unless instance.state.to_s == 'active'
          new(instance)
        end.compact
      end

      def get_retired_reserved_instances
        return @retired_reserved_instances if @retired_reserved_instances
        @retired_reserved_instances = rds.describe_reserved_db_instances.reserved_db_instances.map do |instance|
          next unless instance.state == 'retired'
          new(instance)
        end.compact
      end
    end

    attr_accessor :id, :name, :multi_az, :scope, :instance_type, :engine, :count, :tag_value, :tag_reason, :expiration_date
    def initialize(rds_instance, account_id=nil, tag_name=nil, rds=nil)
      if rds_instance.class.to_s == "Aws::RDS::Types::ReservedDBInstance"
        self.id = rds_instance.reserved_db_instances_offering_id
        self.scope = nil
        self.multi_az = rds_instance.multi_az ? "Multi-AZ" : "Single-AZ"
        self.instance_type = rds_instance.db_instance_class
        self.engine = engine_helper(rds_instance.product_description)
        self.count = rds_instance.db_instance_count
        self.expiration_date = rds_instance.start_time + rds_instance.duration if rds_instance.state == 'retired'
      elsif rds_instance.class.to_s == "Aws::RDS::Types::DBInstance"
        self.id = rds_instance.db_instance_identifier
        self.name = rds_instance.db_name
        self.scope = nil
        self.multi_az = rds_instance.multi_az ? "Multi-AZ" : "Single-AZ"
        self.instance_type = rds_instance.db_instance_class
        self.engine = engine_helper(rds_instance.engine)
        self.count = 1

        if tag_name
          region = rds_instance.availability_zone.split(//).first(9).join
          region = "us-east-1" if region == "Multiple"
          arn = "arn:aws:rds:#{region}:#{account_id}:db:#{self.id}"

           # go through to see if the tag we're looking for is one of them
          rds.list_tags_for_resource(resource_name: arn).tag_list.each do |tag|
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
      "#{engine} #{multi_az} #{instance_type}"
    end

    def no_reserved_instance_tag_value
      tag_value
    end

    # Generates a name based on the RDS engine or product description
    def engine_helper(engine)
      case engine.downcase
      when 'aurora'
        'Aurora'
      when 'mariadb'
        'MariaDB'
      when 'mysql'
        'MySQL'
      when 'oracle-ee',     'oracle-ee(byol)'
        'Oracle EE'
      when 'oracle-se',     'oracle-se(byol)'
        'Oracle SE'
      when 'oracle-se1',    'oracle-se1(li)'
        'Oracle SE One'
      when 'oracle-se2',    'oracle-se2 (byol)' # extra space required
        'Oracle SE Two'
      when 'postgres',      'postgresql'
        'PostgreSQL'
      when 'sqlserver-ee',  'sqlserver-ee(li)'
        'SQL Server EE'
      when 'sqlserver-ex',  'sqlserver-ex(li)'
        'SQL Server EX'
      when 'sqlserver-se',  'sqlserver-se(byol)'
        'SQL Server SE'
      when 'sqlserver-web', 'sqlserver-web(li)'
        'SQL Server Web'
      else
        'Unknown DB Engine'
      end
    end
    private :engine_helper
  end
end
