require "sport_ngin_aws_auditor"

module SportNginAwsAuditor
  describe Instance do
    it "should make a reserved instance with proper attributes" do
      instance = Instance.new("Windows VPC  m1.large", {count: 4, region_based: true}, 'us-east')
      expect(instance).to be_an_instance_of(Instance)
      expect(instance.category).to eq("reserved")
      expect(instance.type).to eq("Windows VPC us-east m1.large")
      expect(instance.count).to eq(4)
      expect(instance.tagged?).to eq(false)
      expect(instance.reserved?).to eq(true)
    end

    it "should make a running instance with proper attributes" do
      instance = Instance.new("Windows VPC us-east-1e m1.large", {count: -1, region_based: false}, 'us-east')
      expect(instance).to be_an_instance_of(Instance)
      expect(instance.category).to eq("running")
      expect(instance.type).to eq("Windows VPC us-east-1e m1.large")
      expect(instance.count).to eq(-1.abs)
    end

    it "should make an instance with a tag with proper attributes" do
      instance = Instance.new("Windows VPC us-east-1e m1.large with tag", {count: 4, name: 'example-instance-name', tag_reason: 'This is an example', tag_value: '09/12/2015', region_based: false}, 'us-east')
      expect(instance).to be_an_instance_of(Instance)
      expect(instance.category).to eq("tagged")
      expect(instance.type).to eq("Windows VPC us-east-1e m1.large")
      expect(instance.count).to eq(4)
      expect(instance.name).to eq('example-instance-name')
      expect(instance.reason).to eq('This is an example')
      expect(instance.tag_value).to eq('09/12/2015')
      expect(instance.tagged?).to eq(true)
      expect(instance.running?).to eq(false)
    end
  end
end
