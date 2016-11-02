require 'highline/import'
require 'colorize'
require_relative "../notify_slack"
require_relative "../instance"
require_relative "../audit_data"

module SportNginAwsAuditor
  module Scripts
    class Audit
      extend AWSWrapper

      class << self
        attr_accessor :options
      end

      def self.execute(environment, options=nil, global_options=nil)
        aws(environment, global_options[:aws_roles])
        @options = options
        slack = options[:slack]
        no_selection = !(options[:ec2] || options[:rds] || options[:cache])

        if options[:no_tag]
          tag_name = nil
        else
          tag_name = options[:tag]
        end

        cycle = [["EC2Instance", options[:ec2]],
                 ["RDSInstance", options[:rds]],
                 ["CacheInstance", options[:cache]]]

        if !slack
          print "Gathering info, please wait..."; print "\r"
        else
          puts "Condensed results from this audit will print into Slack instead of directly to an output."
        end

        cycle.each do |c|
          audit_results = AuditData.new(options[:instances], options[:reserved], c.first, tag_name)
          audit_results.gather_data
          print_data(slack, audit_results, c.first, environment) if (c.last || no_selection)
        end
      end

      def self.print_data(slack, audit_results, class_type, environment)
        audit_results.data.sort_by! { |instance| [instance.category, instance.type] }

        if slack
          print_to_slack(audit_results, class_type, environment)
        elsif options[:reserved] || options[:instances]
          puts header(class_type)
          audit_results.data.each{ |instance| say "<%= color('#{instance.type}: #{instance.count}', :white) %>" }
        else
          retired_ris = audit_results.retired_ris
          retired_tags = audit_results.retired_tags

          puts header(class_type)
          audit_results.data.each{ |instance| colorize(instance) }

          say_retired_ris(retired_ris, class_type, environment) unless retired_ris.empty?
          say_retired_tags(retired_tags, class_type, environment) unless retired_tags.empty?
        end
      end

      def self.say_retired_ris(retired_ris, class_type, environment)
        say "The following reserved #{class_type}Instances have recently expired in #{environment}:"
        retired_ris.each { |ri| say "#{ri.to_s} (#{ri.count}) on #{ri.expiration_date}" }
      end

      def self.say_retired_tags(retired_tags, class_type, environment)
        say "The following #{class_type}Instance tags have recently expired in #{environment}:"
        retired_tags.each do |tag|
          if tag.reason
            say "#{tag.instance_name} (#{tag.instance_type}) retired on #{tag.value} because of #{tag.reason}"
          else
            say "#{tag.instance_name} (#{tag.instance_type}) retired on #{tag.value}"
          end
        end
      end

      def self.colorize(instance)
        name = instance.type
        count = instance.count
        color, rgb, prefix = color_chooser(instance)
        if instance.tagged?
          if instance.reason
            puts "#{prefix} #{name} (expiring on #{instance.tag_value} because of #{instance.reason})".blue
          else
            say "<%= color('#{prefix} #{name} (expiring on #{instance.tag_value})', :#{color}) %>"
          end
        else
          say "<%= color('#{prefix} #{name}: #{count}', :#{color}) %>"
        end
      end

      def self.print_to_slack(audit_results, class_type, environment)
        discrepancy_array = []
        tagged_array = []

        audit_results.data.each do |instance|
          unless instance.matched? || instance.tagged?
            discrepancy_array.push(instance)
          end
        end

        unless discrepancy_array.empty?
          print_discrepancies(discrepancy_array, audit_results, class_type, environment)
        end

        audit_results.data.each do |instance|
          if instance.tagged?
            tagged_array.push(instance)
          end
        end

        unless tagged_array.empty?
          print_tagged(tagged_array, audit_results, class_type, environment)
        end

        retired_ris = audit_results.retired_ris
        retired_tags = audit_results.retired_tags

        print_retired_ris(retired_ris, class_type, environment) unless retired_ris.empty?
        print_retired_tags(retired_tags, class_type, environment) unless retired_tags.empty?
      end

      def self.print_discrepancies(discrepancy_array, audit_results, class_type, environment)
        title = "Some #{class_type} discrepancies for #{environment} exist:\n"
        slack_instances = NotifySlack.new(title)

        discrepancy_array.each do |discrepancy|
          type = discrepancy.type
          count = discrepancy.count
          color, rgb, prefix = color_chooser(discrepancy)

          unless discrepancy.tagged?
            text = "#{prefix} #{type}: #{count}"
            slack_instances.attachments.push({"color" => rgb, "text" => text, "mrkdwn_in" => ["text"]})
          end
        end

        slack_instances.perform        
      end

      def self.print_tagged(tagged_array, audit_results, class_type, environment)
        title = "There are currently some tagged #{class_type}s in #{environment}:\n"
        slack_instances = NotifySlack.new(title)

        tagged_array.each do |tagged|
          type = tagged.type
          count = tagged.count
          color, rgb, prefix = color_chooser(tagged)
          
          if tagged.reason
            text = "#{prefix} #{type} (expiring on #{tagged.tag_value} because of #{tagged.reason})"
          else
            text = "#{prefix} #{type}: #{count} (expiring on #{tagged.tag_value})"
          end

          slack_instances.attachments.push({"color" => rgb, "text" => text, "mrkdwn_in" => ["text"]})
        end

        slack_instances.perform
      end

      def self.print_retired_ris(retired_ris, class_type, environment)
        message = "The following reserved #{class_type}s have recently expired in #{environment}:\n"

        retired_ris.each do |ri|
          name = ri.to_s
          count = ri.count
          expiration_date = ri.expiration_date
          message << "*#{name}* (#{count}) on *#{expiration_date}*\n"
        end
          
        slack_retired_ris = NotifySlack.new(message)
        slack_retired_ris.perform
      end

      def self.print_retired_tags(retired_tags, class_type, environment)
        message = "The following #{class_type} tags have recently expired in #{environment}:\n"

        retired_tags.each do |tag|
          if tag.reason
            message << "*#{tag.instance_name}* (#{tag.instance_type}) retired on *#{tag.value}* because of #{tag.reason}\n"
          else
            message << "*#{tag.instance_name}* (#{tag.instance_type}) retired on *#{tag.value}*\n"
          end
        end

        slack_retired_tags = NotifySlack.new(message)
        slack_retired_tags.perform
      end

      def self.color_chooser(instance)
        if instance.tagged?
          return "blue", "#0000CC", "TAGGED -"
        elsif instance.running?
          return "yellow", "#FFD700", "MISSING RI -"
        elsif instance.matched?
          return "green", "#32CD32", "MATCHED RI -"
        elsif instance.reserved?
          return "red", "#BF1616", "UNUSED RI -"
        end
      end

      def self.header(type, length = 50)
        type.upcase!.slice! "INSTANCE"
        half_length = (length - type.length)/2.0 - 1
        [
          "*" * length,
          "*" * half_length.floor + " #{type} " + "*" * half_length.ceil,
          "*" * length
        ].join("\n")
      end

    end
  end
end
