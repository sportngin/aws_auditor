require "sport_ngin_aws_auditor"

module SportNginAwsAuditor
  describe AuditData do
    before :each do
      @instance = double('instance')
      @instance1 = double('ec2_instance1', availability_zone: 'us-east-1b')
      @instance2 = double('ec2_instance2')
      @instance3 = double('ec2_instance3')
      @instance4 = double('ec2_instance4')
      @ec2_instances = [@instance1, @instance2]
      @retired_ris = [@instance3, @instance4]
      allow(SportNginAwsAuditor::EC2Instance).to receive(:get_instances).and_return(@ec2_instances)
      allow(SportNginAwsAuditor::EC2Instance).to receive(:get_reserved_instances).and_return(@ec2_instances)
      allow(SportNginAwsAuditor::EC2Instance).to receive(:get_retired_tags).and_return([])
      allow(SportNginAwsAuditor::EC2Instance).to receive(:filter_instances_with_tags).and_return([])
      allow(SportNginAwsAuditor::EC2Instance).to receive(:filter_instances_without_tags).and_return(@ec2_instances)
      allow(SportNginAwsAuditor::EC2Instance).to receive(:instance_count_hash).and_return({'instance1' => 1,
                                                                                           'instance2' => 1})
      allow(SportNginAwsAuditor::EC2Instance).to receive(:apply_tagged_instances).and_return({'instance1' => 1,
                                                                                                      'instance2' => 1})
      allow(SportNginAwsAuditor::EC2Instance).to receive(:compare).and_return({'instance1' => 1,
                                                                               'instance2' => 1})
      allow(SportNginAwsAuditor::EC2Instance).to receive(:get_recent_retired_reserved_instances).and_return(@retired_ris)
      allow(Instance).to receive(:new).and_return(@instance)
    end

    context '#initialization' do
      it 'should gather instance data' do
        audit_results = AuditData.new(true, false, "EC2Instance", "no-reserved-instance")
        expect(audit_results.selected_audit_type).to eq("instances")
      end

      it 'should gather reserved instance data' do
        audit_results = AuditData.new(false, true, "EC2Instance", "no-reserved-instance")
        expect(audit_results.selected_audit_type).to eq("reserved")
      end

      it 'should by default gather instance data' do
        audit_results = AuditData.new(true, true, "EC2Instance", "no-reserved-instance")
        expect(audit_results.selected_audit_type).to eq("instances")
      end

      it 'should gather all data to compare' do
        audit_results = AuditData.new(false, false, "EC2Instance", "no-reserved-instance")
        expect(audit_results.selected_audit_type).to eq("all")
      end

      it 'should use EC2Instance class' do
        audit_results = AuditData.new(false, false, "EC2Instance", "no-reserved-instance")
        expect(audit_results.klass).to eq(SportNginAwsAuditor::EC2Instance)
      end

      it 'should use EC2Instance class' do
        audit_results = AuditData.new(false, false, "EC2Instance", "no-reserved-instance")
        expect(audit_results.tag_name).to eq("no-reserved-instance")
      end
    end

    context '#instances?' do
      it 'should return true' do
        audit_results = AuditData.new(true, false, "EC2Instance", "no-reserved-instance")
        expect(audit_results.instances?).to eq(true)
      end

      it 'should return true' do
        audit_results = AuditData.new(false, true, "EC2Instance", "no-reserved-instance")
        expect(audit_results.instances?).to eq(false)
      end
    end

    context '#reserved?' do
      it 'should return true' do
        audit_results = AuditData.new(true, false, "EC2Instance", "no-reserved-instance")
        expect(audit_results.reserved?).to eq(false)
      end

      it 'should return true' do
        audit_results = AuditData.new(false, true, "EC2Instance", "no-reserved-instance")
        expect(audit_results.reserved?).to eq(true)
      end
    end

    context '#all?' do
      it 'should return true' do
        audit_results = AuditData.new(true, false, "EC2Instance", "no-reserved-instance")
        expect(audit_results.all?).to eq(false)
      end

      it 'should return true' do
        audit_results = AuditData.new(false, false, "EC2Instance", "no-reserved-instance")
        expect(audit_results.all?).to eq(true)
      end
    end

    context '#gather_data' do
      it 'should gather some empty results by comparison' do
        audit_results = AuditData.new(false, false, "EC2Instance", "no-reserved-instance")
        audit_results.gather_data
        expect(audit_results.data).to eq([@instance, @instance])
        expect(audit_results.retired_tags).to eq([])
        expect(audit_results.retired_ris).to eq(@retired_ris)
      end

      it 'should gather some empty results from just instances' do
        audit_results = AuditData.new(true, false, "EC2Instance", "no-reserved-instance")
        audit_results.gather_data
        expect(audit_results.data).to eq([@instance, @instance])
        expect(audit_results.retired_tags).to eq([])
        expect(audit_results.retired_ris).to eq(nil)
      end

      it 'should gather some empty results from just reserved' do
        audit_results = AuditData.new(false, true, "EC2Instance", "no-reserved-instance")
        audit_results.gather_data
        expect(audit_results.data).to eq([@instance, @instance])
        expect(audit_results.retired_tags).to eq(nil)
        expect(audit_results.retired_ris).to eq(nil)
      end
    end

    context '#gather_instances_data' do
      it 'should gather some instances data but not convert' do
        audit_results = AuditData.new(true, false, "EC2Instance", "no-reserved-instance")
        result1, result2 = audit_results.gather_instances_data
        expect(result1).to eq({'instance1' => 1, 'instance2' => 1})
        expect(result2).to eq([])
      end
    end

    context '#gather_all_data' do
      it 'should gather some comparison data but not convert' do
        audit_results = AuditData.new(false, false, "EC2Instance", "no-reserved-instance")
        result1, result2, result3 = audit_results.gather_all_data
        expect(result1).to eq({'instance1' => 1, 'instance2' => 1})
        expect(result2).to eq([])
        expect(result3).to eq(@retired_ris)
      end
    end

    context '#gather_region' do
      it 'should gather the region from an instance' do
        audit_results = AuditData.new(false, false, "EC2Instance", "no-reserved-instance")
        audit_results.gather_region(@ec2_instances)
        expect(audit_results.region).to eq('us-east')
      end
    end
  end
end
