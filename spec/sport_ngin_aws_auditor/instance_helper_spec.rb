require "sport_ngin_aws_auditor"

module SportNginAwsAuditor
  describe InstanceHelper do
    before :each do
      @ec2_instance1 = double('ec2_instance', instance_id: "i-thisisfake",
                                               instance_type: "t2.small",
                                               vpc_id: "vpc-alsofake",
                                               platform: "Linux VPC",
                                               state: nil,
                                               placement: nil,
                                               tags: nil,
                                               class: "Aws::EC2::Types::Instance",
                                               key_name: 'Example-instance-01',
                                               availability_zone: 'us-east-1b')
      @ec2_instance2 = double('ec2_instance', instance_id: "i-thisisfake",
                                               instance_type: "t2.medium",
                                               vpc_id: "vpc-alsofake",
                                               platform: "Windows",
                                               state: nil,
                                               placement: nil,
                                               tags: nil,
                                               class: "Aws::EC2::Types::Instance",
                                               key_name: 'Example-instance-02',
                                               availability_zone: 'us-east-1b')
      @reserved_ec2_instance1 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisalsofake",
                                                                instance_type: "t2.small",
                                                                product_description: "Linux/UNIX (Amazon VPC)",
                                                                state: "active",
                                                                availability_zone: "us-east-1b",
                                                                instance_count: 2,
                                                                scope: 'Availability Zone',
                                                                class: "Aws::EC2::Types::ReservedInstances")
      @reserved_ec2_instance2 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisfake!!",
                                                                instance_type: "t2.medium",
                                                                product_description: "Windows",
                                                                state: "active",
                                                                availability_zone: "us-east-1b",
                                                                instance_count: 4,
                                                                scope: 'Availability Zone',
                                                                class: "Aws::EC2::Types::ReservedInstances")
      @region_reserved_ec2_instance1 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisalsofake",
                                                                instance_type: "t2.small",
                                                                product_description: "Linux/UNIX (Amazon VPC)",
                                                                state: "active",
                                                                availability_zone: nil,
                                                                instance_count: 2,
                                                                scope: 'Region',
                                                                class: "Aws::EC2::Types::ReservedInstances")
      @region_reserved_ec2_instance2 = double('reserved_ec2_instance', reserved_instances_id: "12345-dfas-1234-asdf-thisisfake!!",
                                                                instance_type: "t2.medium",
                                                                product_description: "Windows",
                                                                state: "active",
                                                                availability_zone: nil,
                                                                instance_count: 4,
                                                                scope: 'Region',
                                                                class: "Aws::EC2::Types::ReservedInstances")
      @ec2_instances = [@ec2_instance1, @ec2_instance2]
      @reserved_instances = [@reserved_ec2_instance2, @reserved_ec2_instance1]
      @region_reserved_instances = [@region_reserved_ec2_instance2, @region_reserved_ec2_instance1]
      @all_reserved_instances = [@reserved_ec2_instance2, @reserved_ec2_instance1, @region_reserved_ec2_instance2, @region_reserved_ec2_instance1]
      allow(SportNginAwsAuditor::EC2Instance).to receive(:get_instances).and_return(@ec2_instances)
      allow(SportNginAwsAuditor::EC2Instance).to receive(:get_reserved_instances).and_return(@all_reserved_instances)
      allow(SportNginAwsAuditor::EC2Instance).to receive(:get_retired_tags).and_return([])
      allow(@ec2_instance1).to receive(:count).and_return(1)
      allow(@ec2_instance2).to receive(:count).and_return(1)
      allow(@ec2_instance1).to receive(:to_s).and_return('Linux VPC us-east-1b t2.small')
      allow(@ec2_instance2).to receive(:to_s).and_return('Windows us-east-1b t2.medium')
      allow(@ec2_instance1).to receive(:name).and_return(@ec2_instance1.key_name)
      allow(@ec2_instance2).to receive(:name).and_return(@ec2_instance2.key_name)
      allow(@ec2_instance1).to receive(:tag_reason).and_return(nil)
      allow(@ec2_instance2).to receive(:tag_reason).and_return(nil)
      allow(@ec2_instance1).to receive(:tag_value).and_return(nil)
      allow(@ec2_instance2).to receive(:tag_value).and_return(nil)
      allow(@reserved_ec2_instance1).to receive(:count).and_return(2)
      allow(@reserved_ec2_instance2).to receive(:count).and_return(2)
      allow(@reserved_ec2_instance1).to receive(:to_s).and_return('Linux VPC us-east-1b t2.small')
      allow(@reserved_ec2_instance2).to receive(:to_s).and_return('Windows us-east-1b t2.medium')
      allow(@region_reserved_ec2_instance1).to receive(:platform).and_return('Linux VPC')
      allow(@region_reserved_ec2_instance1).to receive(:instance_type).and_return('t2.small')
      allow(@region_reserved_ec2_instance1).to receive(:count).and_return(2)
      allow(@region_reserved_ec2_instance2).to receive(:platform).and_return('Windows')
      allow(@region_reserved_ec2_instance2).to receive(:instance_type).and_return('t2.medium')
      allow(@region_reserved_ec2_instance2).to receive(:count).and_return(4)
      allow(@region_reserved_ec2_instance1).to receive(:to_s).and_return('Linux VPC  t2.small')
      allow(@region_reserved_ec2_instance2).to receive(:to_s).and_return('Windows  t2.medium')
    end

    context '#instance_count_hash' do
      it 'should add the instances to the hash of differences' do
        klass = SportNginAwsAuditor::EC2Instance
        result = klass.instance_count_hash(@ec2_instances)
        expect(result).to eq({'Linux VPC us-east-1b t2.small' => {count: 1, region_based: false}, 'Windows us-east-1b t2.medium' => {count: 1, region_based: false}})
      end
    end

    context '#apply_tagged_instances' do
      it 'should add the instances to the hash of differences' do
        klass = SportNginAwsAuditor::EC2Instance
        result = klass.apply_tagged_instances(@ec2_instances, {})
        expect(result).to eq({'Linux VPC us-east-1b t2.small with tag' => {count: 1, name: @ec2_instance1.key_name, tag_reason: nil, tag_value: nil, region_based: false},
                              'Windows us-east-1b t2.medium with tag' => {count: 1, name: @ec2_instance2.key_name, tag_reason: nil, tag_value: nil, region_based: false}})
      end
    end

    context '#apply_region_ris' do
      it 'should factor in the region based RIs into the counting when there is a mixture of region based and non region based' do
        klass = SportNginAwsAuditor::EC2Instance
        allow(@ec2_instance1).to receive(:count).and_return(5)
        allow(@ec2_instance2).to receive(:count).and_return(5)
        allow(@region_reserved_ec2_instance1).to receive(:count=)
        allow(@region_reserved_ec2_instance2).to receive(:count=)
        instance_hash = klass.instance_count_hash(@ec2_instances)
        ris = klass.instance_count_hash(@reserved_instances)
        differences = Hash.new()
        instance_hash.keys.concat(ris.keys).uniq.each do |key|
          instance_count = instance_hash.has_key?(key) ? instance_hash[key][:count] : 0
          ris_count = ris.has_key?(key) ? ris[key][:count] : 0
          differences[key] = {count: ris_count - instance_count, region_based: false}
        end
        result = klass.apply_region_ris(@region_reserved_instances, differences)
        expect(differences).to eq({"Linux VPC us-east-1b t2.small"=>{count: 0, region_based: false}, "Windows us-east-1b t2.medium"=>{count: 0, region_based: false},
                                   "Linux VPC  t2.small" => {count: 2, region_based: true}, "Windows  t2.medium" => {count: 4, region_based: true}})
      end

      it 'should factor in the region based RIs into the counting when there are no zone specific RIs' do
        klass = SportNginAwsAuditor::EC2Instance
        allow(@ec2_instance1).to receive(:count).and_return(-2)
        allow(@ec2_instance2).to receive(:count).and_return(5)
        allow(@region_reserved_ec2_instance1).to receive(:count=)
        allow(@region_reserved_ec2_instance2).to receive(:count=)
        instance_hash = klass.instance_count_hash(@ec2_instances)
        result = klass.apply_region_ris(@region_reserved_instances, instance_hash)
        expect(instance_hash).to eq({"Linux VPC us-east-1b t2.small"=>{count: 0, region_based: false}, "Windows us-east-1b t2.medium"=>{count: 5, region_based: false},
                                     "Linux VPC  t2.small" => {count: 2, region_based: true}, "Windows  t2.medium" => {count: 4, region_based: true}})
      end
    end

    context '#filter_ris_region_based' do
      it 'should filter all of the region based RIs out of the entire RI list' do
        klass = SportNginAwsAuditor::EC2Instance
        result = klass.filter_ris_region_based(@all_reserved_instances)
        expect(result).to eq(@region_reserved_instances)
      end
    end

    context '#filter_ris_availability_zone' do
      it 'should remove all of the region based RIs out of the entire RI list' do
        klass = SportNginAwsAuditor::EC2Instance
        result = klass.filter_ris_availability_zone(@all_reserved_instances)
        expect(result).to eq(@reserved_instances)
      end
    end

    context '#gather_instance_tag_date' do
      it 'should remove all of the region based RIs out of the entire RI list' do
        klass = SportNginAwsAuditor::EC2Instance
        allow(@ec2_instance1).to receive(:no_reserved_instance_tag_value).and_return('08/29/1995')
        result = klass.gather_instance_tag_date(@ec2_instance1)
        date_hash = Date._strptime('08/29/1995', '%m/%d/%Y')
        value = Date.new(date_hash[:year], date_hash[:mon], date_hash[:mday]) if date_hash
        expect(result).to eq(value)
      end
    end

  end
end
