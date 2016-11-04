arg :aws_account
desc 'Audits Reserved Instance Counts'
command 'audit' do |c|
  c.switch [:e, :ec2], :desc => "Only audit EC2 instances"
  c.switch [:d, :rds], :desc => "Only audit RDS instances"
  c.switch [:c, :cache], :desc => "Only audit ElastiCache instances"
  c.switch [:r, :reserved], :desc => "Shows reserved instance counts"
  c.switch [:i, :instances], :desc => "Shows current instance counts"
  c.flag [:t, :tag], :default_value => "no-reserved-instance", :desc => "Read a tag and group separately during audit"
  c.switch [:n, :no_tag], :desc => "Ignore all tags during audit"
  c.switch [:s, :slack], :desc => "Will print condensed version of audit to a Slack channel"
  c.switch [:z, :zone_output], :desc => "Will print the Missing RIs and Tagged instances with zones"
  c.action do |global_options, options, args|
    require_relative '../scripts/audit'
    raise ArgumentError, 'You must specify an AWS account' unless args.first
    SportNginAwsAuditor::Scripts::Audit.execute(args.first, options, global_options)
  end
end
