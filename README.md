# SportNginAwsAuditor
Audits your AWS accounts to find discrepancies between the number of running instances and purchased reserved instances.

### DEPRECATION NOTICE
This repo is being deprecated in favor of https://github.com/sportngin/aws-auditor. Please use that repository for any future updates to the SportsEngine AWS Auditor!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sport_ngin_aws_auditor'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sport_ngin_aws_auditor

## How-to

### AWS Setup
There are three ways to authenticate AWS. The first is to create an `~/.aws/credentials` file that should have the following structure:

```
[ACCOUNT 1]
aws_access_key_id = [AWS ACCESS KEY]
aws_secret_access_key = [SECRET ACCESS KEY]

[ACCOUNT 2]
aws_access_key_id = [AWS ACCESS KEY]
aws_secret_access_key = [SECRET ACCESS KEY]

[ACCOUNT 3]
aws_access_key_id = [AWS ACCESS KEY]
aws_secret_access_key = [SECRET ACCESS KEY]
```

Then this gem will use [AWS Shared Credentials](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) with your credentials file. This is the default. If you'd like to pass a different config file, use the `--config` flag. 

The second way to authenticate is through [User Roles](http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html), then use the flag `aws_roles`:

    $ sport-ngin-aws-auditor --aws_roles [command] account1

The third way to authenticate is authentication by assumed roles. To indicate this, use the `--assume_roles` switch. If using assumed roles, then the auditor needs a role name, which is defaulted to 'CrossAccountAuditorAccess'. Alternatively, a role name can be passed in with `--role_name`. Lastly, if using assumed roles, the auditor will also need an arn id. Identify this with the `--arn_id` option. The arn id is the identifying digits of the AWS arn arn:aws:iam::999999999999:role/#{role_name}.

```
$ sport-ngin-aws-auditor --assume_roles --role_name=MyRoleName --arn_id=999999999999 [command] account1
```

### Google Setup (optional)
You can export audit information to a Google Spreadsheet, but you must first follow “Create a client ID and client secret” on [this page](https://developers.google.com/drive/web/auth/web-server) to get a client ID and client secret for OAuth. Then create a `.google.yml` in your home directory with the following structure.

```yaml
---
credentials:
  client_id: 'GOOGLE_CLIENT_ID'
  client_secret: 'GOOGLE_CLIENT_ID'
file:
  path: 'DESIRED_PATH_TO_FILE' # optional, creates in root directory otherwise
  name: 'NAME_OF_FILE'
```
 
## Usage

### Global Options

When auditing, it can be handy to pass in a special name to be printed describing the account that's being audited. This can be done through the `--display=Example` flag.

Lastly, a user can tell the auditor which region to run the auditor in through the `--region=us-east-1` flag. If no region is specified, it will be run in every U.S. region: us-east-1, us-east-2, us-west-1, and us-west-2.

### The Audit Command

To find discrepancies between number of running instances and purchased instances, run:

    $ sport-ngin-aws-auditor audit account1

Any running instances that are not matched with a reserved instance with show up as yellow, the reserved instances that are not matched with a running instance will show up in red, and any reserved instances and running instances that match will show up in green. Any instances in blue either have a special tag or are being ignored.

You can also audit just EC2 instances, just RDS instances, or just CacheInstances. To do this, use `--ec2`, `--rds`, and `--cache` respectively. Or, you can use the audit account to just show counts of reserved instances and reserved instances. To do that, use the `--reserved` and `--instances` options.

The tag can be specified through the `--tag=tag_name` option. Or, it will be defaulted to 'no-reserved-instance'. This means that when an instance is found that contains the tag 'no-reserved-instance', it will evaluate it separately from the other running instances, and list it in blue.

If a user wants to completely ignore tags, then use the `--no_tag` switch to turn tags off.

If an instance is ignored, it means that the name of the instance matches one of the ignore_instances_patterns. These patterns can be specified through the `--ignore_instances_patterns='string1, string2, string3'` flag, or they will be defaulted to 'kitchen' and 'auto'. Like the tagged instances, if an instance name matches one of these patterns, it will be listed separately and not used in calculating red/yellow/green instances.

To ignore instance regexes, pass in an empty string or nil as the instances.

To print a condensed version of the discrepancies to a Slack account (instead of printing to the terminal), run:

    $ sport-ngin-aws-auditor audit --slack account1

For this option to use a designated channel, username, icon/emoji, and webhook, set up a global config file that should look like this:

```
slack:
  username: [AN AWESOME USERNAME]
  icon_url: [AN AWESOME IMAGE]
  channel: "#[AN SUPER COOL CHANNEL]"
  webhook: [YOUR WEBHOOK URL]
```

The default is for the file to be called `.aws_auditor.yml` in your home directory, but to pass in a different path, feel free to pass it in via command line like this:

    $ sport-ngin-aws-auditor --config="/PATH/TO/FILE/slack_file_creds.yml" audit --slack staging

The webhook urls for slack can be obtained [here](https://api.slack.com/incoming-webhooks).

In AWS, when booting reserved instances, a user can choose between an availability zone RI, where the RI will cover an instance in that specific zone, such as us-east-1b, or it can be a region RI, where it will just cover any instance in the region us-east-1 (that matches in size, of course). Therefore, there are two ways to audit the data to account for this. To print the data with zones, use the `--zone_output` option. Without the `--zone_output`, the data will ignore zone-based data to just print region-based data. 

### The Inspect Command

To list information about all running instances in your account, run:

    $ sport-ngin-aws-auditor inspect account1

### The Export Command

To export audit information to a Google Spreadsheet, make sure you added a `.google.yml` and run:

    $ sport-ngin-aws-auditor export -d account1
    
## Contributing

1. Fork it (https://github.com/sportngin/sport_ngin_aws_auditor/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
