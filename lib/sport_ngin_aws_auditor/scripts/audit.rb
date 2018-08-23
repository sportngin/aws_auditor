require 'highline/import'
require 'colorize'
require 'aws-sdk'
require_relative "../notify_slack"
require_relative "../instance"
module SportNginAwsAuditor
  module Scripts
    class Audit
      class << self
        attr_accessor :options, :audit_results
      end

      #################### EXECUTION ####################

      def self.execute(environment, options, global_options)
        begin
          AWS.configure(environment, global_options)
          collect_options(environment, options, global_options)
          print_title
          @regions.each { |region| audit_region(region) }
        rescue StandardError => e
          if options[:slack]
            NotifySlack.new("Sorry, something seems to have gone wrong.", options[:config_json]).perform
          else
            puts "Sorry, something seems to have gone wrong."
          end
          raise e
        end
      end

      # We do this method for each region we're auditing
      def self.audit_region(region)
        @region_previously_printed = false
        @message = ""
        @instance_types.each { |type| audit_instance_type(type, region) }
        add_region_to_message(region) unless @message == "" || @region_previously_printed || @slack
        print_message unless @slack
      end

      # We do this method for each type of instance in each region we're auditing
      def self.audit_instance_type(type, region)
        @class = type.first
        @audit_results = AuditData.new({:instances => options[:instances], :reserved => options[:reserved],
                                        :class => type.first.to_s, :tag_name => @tag_name,
                                        :regexes => @ignore_instances_regexes, :region => region})
        @audit_results.gather_data

        unless @audit_results.data.nil? || @audit_results.data.empty?
          add_instance_type_to_message(type)
          print_audit_results(region) if (type.last || @no_selection)
        end
      end

      def self.print_audit_results(region)
        @audit_results.data.each do |instance|
          instance.type = !@zone_output && (instance.tagged? || instance.running?) ? print_without_zone(instance.type) : instance.type
        end

        @audit_results.data = merge_similar_keys(@audit_results.data)
        @audit_results.data.sort_by! { |instance| [instance.category, instance.type] }

        if @slack
          print_to_slack(region)
        elsif options[:reserved] || options[:instances]
          @audit_results.data.each{ |instance| @message << "#{instance.type}: #{instance.count}\n".colorize(:color => :white) }
        else
          print_to_terminal
        end
      end

      #################### PRINTING DATA TO TERMINAL ####################

      def self.print_to_terminal
        say_instances
        say_retired_ris unless @audit_results.retired_ris.empty?
        say_retired_tags unless @audit_results.retired_tags.empty?
      end

      def self.say_instances
        @audit_results.data.each do |instance|
          name_type = instance.type
          count = instance.count
          color, rgb, prefix = color_chooser({:instance => instance, :retired_ri => false, :retired_tag => false})
          
          if instance.tagged?
            if instance.reason
              description = "#{prefix} #{name_type}: (expiring on #{instance.tag_value} because #{instance.reason})\n"
            else
              description = "#{prefix} #{name_type}: (expiring on #{instance.tag_value})\n"
            end
          elsif instance.ignored?
            description = "#{prefix} #{name_type}\n"
          else
            description = "#{prefix} #{name_type}: #{count}\n"
          end

          @message << description.colorize(:color => color)
        end
      end

      def self.say_retired_ris
        retired_ris = @audit_results.retired_ris

        retired_ris.each do |ri|
          color, rgb, prefix = color_chooser({:instance => ri, :retired_ri => true, :retired_tag => false})
          if ri.availability_zone.nil?
            # if ri.to_s = 'Linux VPC t2.small'...
            my_match = ri.to_s.match(/(\w*\s*\w*\s{1})\s*(\s*\S*)/)

            # then platform = 'Linux VPC '...
            platform = my_match[1] if my_match

            # and size = 't2.small'
            size = my_match[2] if my_match

            n = "#{platform}#{@audit_results.region} #{size}"
          else
            n = ri.to_s
          end

          @message << "#{prefix} #{n} (#{ri.count}) on #{ri.expiration_date}\n".colorize(:color => color)
        end
      end

      def self.say_retired_tags
        retired_tags = @audit_results.retired_tags

        retired_tags.each do |tag|
          color, rgb, prefix = color_chooser({:instance => tag, :retired_ri => false, :retired_tag => true})
          if tag.reason
            description ="#{prefix} #{tag.instance_name} (#{tag.instance_type}) retired on #{tag.value} because #{tag.reason}\n"
          else
            description = "#{prefix} #{tag.instance_name} (#{tag.instance_type}) retired on #{tag.value}\n"
          end

          @message << description.colorize(:color => color)
        end
      end

      #################### PRINTING DATA TO SLACK ####################

      def self.print_to_slack(region)
        @slack_message = NotifySlack.new(@message, @options[:config_json])

        print_instances
        print_retired_ris unless @audit_results.retired_ris.empty?
        print_retired_tags unless @audit_results.retired_tags.empty?

        add_region_to_message(region) unless @region_previously_printed
        print_message
        @region_previously_printed = true
        @message = ""
      end

      def self.print_instances
        data_array = @audit_results.data.reject { |instance| instance.matched? }

        if data_array.empty?
          @slack_message.attachments.push({"color" => "#32CD32", "text" => "All RIs are properly matched here!", "mrkdwn_in" => ["text"]})
        else
          data_array.each do |instance|
            name_type = instance.type
            count = instance.count
            color, rgb, prefix = color_chooser({:instance => instance, :retired_ri => false, :retired_tag => false})

            if instance.tagged?
              if instance.reason
                text = "#{prefix} #{name_type}: (expiring on #{instance.tag_value} because #{instance.reason})"
              else
                text = "#{prefix} #{name_type}: (expiring on #{instance.tag_value})"
              end
            elsif instance.ignored?
              text = "#{prefix} #{name_type}"
            else
              text = "#{prefix} #{name_type}: #{count}"
            end

            @slack_message.attachments.push({"color" => rgb, "text" => text, "mrkdwn_in" => ["text"]})
          end
        end
      end

      def self.print_retired_ris
        retired_ris = @audit_results.retired_ris

        retired_ris.each do |ri|
          if ri.availability_zone.nil?
            # if ri.to_s = 'Linux VPC  t2.small'...
            my_match = ri.to_s.match(/(\w*\s*\w*\s{1})\s*(\s*\S*)/)

            # then platform = 'Linux VPC '...
            platform = my_match[1] if my_match

            # and size = 't2.small'
            size = my_match[2] if my_match

            name = "#{platform}#{@audit_results.region} #{size}"
          else
            name = ri.to_s
          end
          
          count = ri.count
          color, rgb, prefix = color_chooser({:instance => ri, :retired_ri => true, :retired_tag => false})
          expiration_date = ri.expiration_date
          text = "#{prefix} #{name} (#{count}) on #{expiration_date}"

          @slack_message.attachments.push({"color" => rgb, "text" => text, "mrkdwn_in" => ["text"]})
        end
      end

      def self.print_retired_tags
        retired_tags = @audit_results.retired_tags

        retired_tags.each do |tag|
          color, rgb, prefix = color_chooser({:instance => tag, :retired_ri => false, :retired_tag => true})

          if tag.reason
            text = "#{prefix} #{tag.instance_name} (#{tag.instance_type}) retired on #{tag.value} because #{tag.reason}"
          else
            text = "#{prefix} #{tag.instance_name} (#{tag.instance_type}) retired on #{tag.value}"
          end

          @slack_message.attachments.push({"color" => rgb, "text" => text, "mrkdwn_in" => ["text"]})
        end
      end

      #################### OTHER HELPFUL METHODS ####################

      def self.gather_regions
        regions = AWS.ec2.describe_regions[:regions]
        regions.collect { |r| r.region_name }
      end

      def self.collect_options(environment, options, global_options)
        @options = options
        @display_name = global_options[:display] || environment
        @slack = options[:slack]
        @no_selection = !(options[:ec2] || options[:rds] || options[:cache])
        @zone_output = options[:zone_output]
        @regions = (global_options[:region].split(', ') if global_options[:region]) || gather_regions

        if options[:no_tag]
          @tag_name = nil
        else
          @tag_name = options[:tag]
        end

        @ignore_instances_regexes = []
        if options[:ignore_instances_patterns]
          options[:ignore_instances_patterns].split(', ').each do |r|
            @ignore_instances_regexes << Regexp.new(r)
          end
        end

        @instance_types = [["EC2Instance", options[:ec2]],
                           ["RDSInstance", options[:rds]],
                           ["CacheInstance", options[:cache]]]
      end

      def self.print_title
        if @slack
          puts "Condensed results from this audit will print into Slack instead of directly to an output."
          NotifySlack.new("_AWS AUDIT FOR #{@display_name}_", @options[:config_json]).perform
        else
          puts "AWS AUDIT FOR #{@display_name}".colorize(:color => :yellow, :background => :red).underline
          puts
        end
      end

      def self.print_message
        unless @message == ""
          if @slack
            @slack_message.perform
          else
            puts @message
          end
        end
      end

      def self.add_region_to_message(region)
        if @slack
          @message.prepend("_REGION: *_#{region}_*_\n")
          @slack_message.text = @message
        else
          @message.prepend("REGION: #{region}\n".colorize(:color => :magenta).underline)
        end
      end

      def self.add_instance_type_to_message(type)
        if @slack
          @message << "*#{type.first}s*\n"
        else
          @message << "#{type.first}s\n".underline
        end
      end

      def self.print_without_zone(type)
        type.sub(/(-\d\w)/, '')
      end

      def self.merge_similar_keys(original_data)
        combined_data = []

        original_data.each_with_index do |instance, index|
          new_count = instance.count

          unless instance.replaced
            for i in index+1..original_data.length-1
              if (original_data[i].type == instance.type) && ((original_data[i].running? && instance.running?) ||
                                                              (original_data[i].reserved? && instance.reserved?) ||
                                                              (original_data[i].matched? && instance.matched?))
                new_count = new_count + original_data[i].count
                original_data[i].replaced = true
              end
            end

            if new_count != instance.count
              combined_data.push(Instance.new(instance.type, nil, nil, instance.category, new_count))
              instance.replaced = true
            end
          end
        end

        original_data.reject { |instance| instance.replaced }.concat(combined_data)
      end

      def self.color_chooser(data)
        if data[:retired_ri]
          return :light_black, "#595959", "RETIRED RI -"
        elsif data[:retired_tag]
          return :light_black, "#595959", "RETIRED TAG -"
        elsif data[:instance].tagged?
          return :blue, "#0000CC", "TAGGED -"
        elsif data[:instance].ignored?
          return :blue, "#0000CC", "IGNORED -"
        elsif data[:instance].running?
          return :yellow, "#FFD700", "MISSING RI -"
        elsif data[:instance].matched?
          return :green, "#32CD32", "MATCHED RI -"
        elsif data[:instance].reserved?
          return :red, "#BF1616", "UNUSED RI -"
        end
      end
    end
  end
end
