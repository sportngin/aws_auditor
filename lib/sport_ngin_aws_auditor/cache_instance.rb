require 'sport_ngin_aws_auditor/instance_helper'

module SportNginAwsAuditor
  class CacheInstance
    extend InstanceHelper

    class << self
      def get_instances(client=AWS.cache, tag_name=nil)
        account_id = AWS.get_account_id
        client.describe_cache_clusters.cache_clusters.map do |instance|
          next unless instance.cache_cluster_status.to_s == 'available'
          new(instance, account_id, tag_name, client)
        end.compact
      end

      def get_reserved_instances(client=AWS.cache)
        client.describe_reserved_cache_nodes.reserved_cache_nodes.map do |instance|
          next unless instance.state.to_s == 'active'
          new(instance)
        end.compact
      end

      def get_retired_reserved_instances(client)
        client.describe_reserved_cache_nodes.reserved_cache_nodes.map do |instance|
          next unless instance.state == 'retired'
          new(instance)
        end.compact
      end
    end

    attr_accessor :id, :name, :instance_type, :scope, :engine, :count, :tag_value, :tag_reason, :expiration_date, :availability_zone
    def initialize(cache_instance, account_id=nil, tag_name=nil, client=nil)
      if cache_instance.class.to_s == "Aws::ElastiCache::Types::ReservedCacheNode"
        self.id = cache_instance.reserved_cache_node_id
        self.name = cache_instance.reserved_cache_node_id
        self.scope = nil
        self.availability_zone = nil
        self.instance_type = cache_instance.cache_node_type
        self.engine = cache_instance.product_description
        self.count = cache_instance.cache_node_count
        self.expiration_date = cache_instance.start_time + cache_instance.duration if cache_instance.state == 'retired'
      elsif cache_instance.class.to_s == "Aws::ElastiCache::Types::CacheCluster"
        self.id = cache_instance.cache_cluster_id
        self.name = cache_instance.cache_cluster_id
        self.scope = nil
        self.availability_zone = nil
        self.instance_type = cache_instance.cache_node_type
        self.engine = cache_instance.engine
        self.count = cache_instance.num_cache_nodes

        if tag_name
          region = cache_instance.preferred_availability_zone.split(//).first(9).join
          region = "us-east-1" if region == "Multiple"
          arn = "arn:aws:elasticache:#{region}:#{account_id}:cluster:#{self.id}"

          # go through to see if the tag we're looking for is one of them
          client.list_tags_for_resource(resource_name: arn).tag_list.each do |tag|
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
      "#{engine.capitalize} #{instance_type}"
    end

    def no_reserved_instance_tag_value
      @tag_value
    end
  end
end
