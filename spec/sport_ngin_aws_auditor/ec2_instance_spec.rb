require "sport_ngin_aws_auditor"

module SportNginAwsAuditor
  describe EC2Instance do

    after :each do
      EC2Instance.instance_variable_set("@instances", nil)
      EC2Instance.instance_variable_set("@reserved_instances", nil)
    end

    context "for normal ec2_instances" do
      before :each do
        state = double('state', name: 'running')
        placement = double('placement', availability_zone: "us-east-1d")
        tag1 = double('tag', key: "cookie", value: "chocolate chip")
        tag2 = double('tag', key: "ice cream", value: "oreo")
        instance_tags = [tag1, tag2]
        ec2_instance1 = double('ec2_instance', instance_id: "i-thisisfake",
                                               instance_type: "t2.large",
                                               vpc_id: "vpc-alsofake",
                                               platform: nil,
                                               state: state,
                                               placement: placement,
                                               tags: instance_tags,
                                               class: "Aws::EC2::Types::Instance",
                                               key_name: 'Example-instance-01')
        ec2_instance2 = double('ec2_instance', instance_id: "i-thisisfake",
                                               instance_type: "t2.large",
                                               vpc_id: "vpc-alsofake",
                                               platform: "Windows",
                                               state: state,
                                               placement: placement,
                                               tags: instance_tags,
                                               class: "Aws::EC2::Types::Instance",
                                               key_name: 'Example-instance-02')
        ec2_reservations = double('ec2_reservations', instances: [ec2_instance1, ec2_instance2])
        ec2_instances = double('ec2_instances', reservations: [ec2_reservations])
        name_tag = { key: "Name", value: "our-app-instance-100" }
        stack_tag = { key: "opsworks:stack", value: "our_app_service_2" }
        client_tags = double('tags', tags: [name_tag, stack_tag])
        ec2_client = double('ec2_client', describe_instances: ec2_instances, describe_tags: client_tags)
        allow(EC2Instance).to receive(:ec2).and_return(ec2_client)
      end

      it "should make an ec2_instance for each instance" do
        instances = EC2Instance.get_instances("tag_name")
        expect(instances.first).to be_an_instance_of(EC2Instance)
        expect(instances.last).to be_an_instance_of(EC2Instance)
      end

      it "should return an array of ec2_instances" do
        instances = EC2Instance.get_instances("tag_name")
        expect(instances).not_to be_empty
        expect(instances.length).to eq(2)
      end

      it "should have proper variables set" do
        instances = EC2Instance.get_instances("tag_name")
        instance = instances.first
        expect(instance.stack_name).to eq("our_app_service_2")
        expect(instance.name).to eq("our-app-instance-100")
        expect(instance.id).to eq("i-thisisfake")
        expect(instance.availability_zone).to eq("us-east-1d")
        expect(instance.instance_type).to eq("t2.large")
        expect(instance.platform).to eq("Linux VPC")
      end

      it "should recognize Windows vs. Linux" do
        instances = EC2Instance.get_instances("tag_name")
        instance1 = instances.first
        instance2 = instances.last
        expect(instance1.platform).to eq("Linux VPC")
        expect(instance2.platform).to eq("Windows VPC")
      end
    end

    context "for reserved_ec2_instances" do
      before :each do
        reserved_ec2_instance1 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisfake!!",
                                                                 instance_type: "t2.medium",
                                                                 product_description: "Windows (Amazon VPC)",
                                                                 state: "active",
                                                                 availability_zone: "us-east-1b",
                                                                 instance_count: 4,
                                                                 scope: 'Availability Zone',
                                                                 class: "Aws::EC2::Types::ReservedInstances")
        reserved_ec2_instance2 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisalsofake",
                                                                 instance_type: "t2.small",
                                                                 product_description: "Linux/UNIX (Amazon VPC)",
                                                                 state: "active",
                                                                 availability_zone: "us-east-1b",
                                                                 instance_count: 2,
                                                                 scope: 'Availability Zone',
                                                                 class: "Aws::EC2::Types::ReservedInstances")
        reserved_ec2_instances = double('reserved_ec2_instances', reserved_instances: [reserved_ec2_instance1, reserved_ec2_instance2])
        ec2_client = double('ec2_client', describe_reserved_instances: reserved_ec2_instances)
        allow(EC2Instance).to receive(:ec2).and_return(ec2_client)
      end

      it "should make a reserved_ec2_instance for each instance" do
        reserved_instances = EC2Instance.get_reserved_instances
        expect(reserved_instances.first).to be_an_instance_of(EC2Instance)
        expect(reserved_instances.last).to be_an_instance_of(EC2Instance)
      end

      it "should return an array of reserved_ec2_instances" do
        reserved_instances = EC2Instance.get_reserved_instances
        expect(reserved_instances).not_to be_empty
        expect(reserved_instances.length).to eq(2)
      end

      it "should have proper variables set" do
        reserved_instances = EC2Instance.get_reserved_instances
        reserved_instance = reserved_instances.first
        expect(reserved_instance.id).to eq("12345-dfas-1234-asdf-thisisfake!!")
        expect(reserved_instance.platform).to eq("Windows VPC")
        expect(reserved_instance.availability_zone).to eq("us-east-1b")
        expect(reserved_instance.instance_type).to eq("t2.medium")
        expect(reserved_instance.count).to eq(4)
      end

      it "should recognize Windows vs. Linux" do
        reserved_instances = EC2Instance.get_reserved_instances
        reserved_instance1 = reserved_instances.first
        reserved_instance2 = reserved_instances.last
        expect(reserved_instance1.platform).to eq("Windows VPC")
        expect(reserved_instance2.platform).to eq("Linux VPC")
      end

      context "for retired_reserved_ec2_instances" do
        before :each do
          @time = Time.now
          retired_reserved_ec2_instance1 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisfake!!",
                                                                           instance_type: "t2.medium",
                                                                           product_description: "Windows (Amazon VPC)",
                                                                           state: "retired",
                                                                           availability_zone: "us-east-1b",
                                                                           instance_count: 4,
                                                                           scope: 'Availability Zone',
                                                                           class: "Aws::EC2::Types::ReservedInstances",
                                                                           end: @time - 86400)
          retired_reserved_ec2_instance2 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisalsofake",
                                                                           instance_type: "t2.small",
                                                                           product_description: "Linux/UNIX (Amazon VPC)",
                                                                           state: "retired",
                                                                           availability_zone: "us-east-1b",
                                                                           instance_count: 2,
                                                                           scope: 'Availability Zone',
                                                                           class: "Aws::EC2::Types::ReservedInstances",
                                                                           end: @time - 86400)
          reserved_ec2_instance1 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisalsofake",
                                                                   instance_type: "t2.small",
                                                                   product_description: "Linux/UNIX (Amazon VPC)",
                                                                   state: "active",
                                                                   availability_zone: "us-east-1b",
                                                                   instance_count: 2,
                                                                   scope: 'Availability Zone',
                                                                   class: "Aws::EC2::Types::ReservedInstances")
          reserved_ec2_instances = double('reserved_ec2_instances', reserved_instances: [retired_reserved_ec2_instance1,
                                                                                         retired_reserved_ec2_instance2,
                                                                                         reserved_ec2_instance1])
          ec2_client = double('ec2_client', describe_reserved_instances: reserved_ec2_instances)
          allow(EC2Instance).to receive(:ec2).and_return(ec2_client)
        end

        it "should make a retired_reserved_ec2_instance for each instance" do
          retired_reserved_instances = EC2Instance.get_retired_reserved_instances
          expect(retired_reserved_instances.first).to be_an_instance_of(EC2Instance)
          expect(retired_reserved_instances.last).to be_an_instance_of(EC2Instance)
        end

        it "should return an array of retired_reserved_ec2_instances" do
          retired_reserved_instances = EC2Instance.get_retired_reserved_instances
          expect(retired_reserved_instances).not_to be_empty
          expect(retired_reserved_instances.length).to eq(2)
        end

        it "should have proper variables set" do
          retired_reserved_instances = EC2Instance.get_retired_reserved_instances
          retired_reserved_instance = retired_reserved_instances.first
          expect(retired_reserved_instance.id).to eq("12345-dfas-1234-asdf-thisisfake!!")
          expect(retired_reserved_instance.platform).to eq("Windows VPC")
          expect(retired_reserved_instance.availability_zone).to eq("us-east-1b")
          expect(retired_reserved_instance.instance_type).to eq("t2.medium")
          expect(retired_reserved_instance.count).to eq(4)
          expect(retired_reserved_instance.expiration_date).to be >= @time - 86500
        end

        it "should recognize Windows vs. Linux" do
          retired_reserved_instances = EC2Instance.get_retired_reserved_instances
          retired_reserved_instance1 = retired_reserved_instances.first
          retired_reserved_instance2 = retired_reserved_instances.last
          expect(retired_reserved_instance1.platform).to eq("Windows VPC")
          expect(retired_reserved_instance2.platform).to eq("Linux VPC")
        end
      end
    end

    context "for returning pretty string formats" do
      it "should return a string version of the name of the reserved_ec2_instance" do
        state = double('state', name: 'running')
        placement = double('placement', availability_zone: "us-east-1d")
        tag1 = double('tag', key: "cookie", value: "chocolate chip")
        tag2 = double('tag', key: "ice cream", value: "oreo")
        instance_tags = [tag1, tag2]
        ec2_instance = double('ec2_instance', instance_id: "i-thisisfake",
                                              instance_type: "t2.large",
                                              vpc_id: "vpc-alsofake",
                                              platform: nil,
                                              state: state,
                                              placement: placement,
                                              tags: instance_tags,
                                              class: "Aws::EC2::Types::Instance",
                                              key_name: 'Example-instance-01')
        ec2_reservations = double('ec2_reservations', instances: [ec2_instance])
        ec2_instances = double('ec2_instances', reservations: [ec2_reservations])
        name_tag = { key: "Name", value: "our-app-instance-100" }
        stack_tag = { key: "opsworks:stack", value: "our_app_service_2" }
        tags = double('tags', tags: [name_tag, stack_tag])
        ec2_client = double('ec2_client', describe_instances: ec2_instances, describe_tags: tags)
        allow(EC2Instance).to receive(:ec2).and_return(ec2_client)
        instances = EC2Instance.get_instances("tag_name")
        instance = instances.first
        expect(instance.to_s).to eq("Linux VPC us-east-1d t2.large")
      end
    end

    context "when bucketizing" do
      before :each do
        state = double('state', name: 'running')
        placement = double('placement', availability_zone: "us-east-1d")
        ec2_instance1 = double('ec2_instance', instance_id: "i-thisisfake",
                                               instance_type: "t2.large",
                                               vpc_id: "vpc-alsofake",
                                               platform: nil,
                                               state: state,
                                               placement: placement,
                                               class: "Aws::EC2::Types::Instance",
                                               key_name: 'Example-instance-01')
        ec2_instance2 = double('ec2_instance', instance_id: "i-alsofake",
                                               instance_type: "t2.small",
                                               vpc_id: "vpc-alsofake",
                                               platform: "Windows",
                                               state: state,
                                               placement: placement,
                                               class: "Aws::EC2::Types::Instance",
                                               key_name: 'Example-instance-01')
        ec2_reservations = double('ec2_reservations', instances: [ec2_instance1, ec2_instance2])
        ec2_instances = double('ec2_instances', reservations: [ec2_reservations])
        name_tag = { key: "Name", value: "our-app-instance-100" }
        stack_tag = { key: "opsworks:stack", value: "our_app_service_2" }
        tags = double('tags', tags: [name_tag, stack_tag])
        ec2_client = double('ec2_client', describe_instances: ec2_instances, describe_tags: tags)
        allow(EC2Instance).to receive(:ec2).and_return(ec2_client)
      end

      it "should return a hash where the first element's key is the opsworks:stack name of the instances" do
        instances = EC2Instance.get_instances
        buckets = EC2Instance.bucketize
        expect(buckets.first.first).to eq("our_app_service_2")
      end

      it "should return a hash where the last element's key is the opsworks:stack name of the instances" do
        instances = EC2Instance.get_instances
        buckets = EC2Instance.bucketize
        expect(buckets.last.first).to eq("our_app_service_2")
      end

      it "should return a hash where each element is a list of ec2_instances" do
        instances = EC2Instance.get_instances
        buckets = EC2Instance.bucketize
        expect(buckets).not_to be_empty
        expect(buckets.length).to eq(1)
        expect(buckets.first.length).to eq(2)
      end
    end
  end
end
