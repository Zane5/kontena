require_relative '../../../spec_helper'

describe Kontena::Workers::ServicePodWorker do
  include RpcClientMocks

  let(:node) { Node.new('id' => 'aa') }
  let(:service_pod) { Kontena::Models::ServicePod.new('id' => 'foo/2', 'instance_number' => 2) }
  let(:subject) { described_class.new(node, service_pod) }

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#ensure_desired_state' do
    before(:each) do
      mock_rpc_client
      allow(rpc_client).to receive(:notification)
    end

    it 'calls ensure_running if container does not exist and service_pod desired_state is running' do
      allow(subject.wrapped_object).to receive(:get_container).and_return(nil)
      allow(service_pod).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_running)
      subject.ensure_desired_state
    end

    it 'calls ensure_running if container is not running and service_pod desired_state is running' do
      container = double(:container, :running? => false, :restarting? => false)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:running?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_running)
      subject.ensure_desired_state
    end

    it 'calls ensure_running if service_revs do not match' do
      container = double(:container, :running? => false, :restarting? => false, :service_rev => 2)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:running?).and_return(true)
      allow(service_pod).to receive(:service_rev).and_return(1)
      expect(subject.wrapped_object).to receive(:ensure_running)
      subject.ensure_desired_state
    end

    it 'calls ensure_stopped if container is running and service_pod desired_state is stopped' do
      container = double(:container, :running? => true, :restarting? => false)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:running?).and_return(false)
      allow(service_pod).to receive(:stopped?).and_return(true)
      expect(subject.wrapped_object).to receive(:ensure_stopped)
      subject.ensure_desired_state
    end

    it 'calls ensure_terminated if container exist and service_pod desired_state is terminated' do
      container = double(:container, :running? => true, :restarting? => false)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      allow(service_pod).to receive(:terminated?).and_return(true)
      allow(service_pod).to receive(:running?).and_return(false)
      allow(service_pod).to receive(:stopped?).and_return(false)
      expect(subject.wrapped_object).to receive(:ensure_terminated)
      subject.ensure_desired_state
    end
  end

  describe '#current_state' do
    it 'returns missing if container is not found' do
      allow(subject.wrapped_object).to receive(:get_container).and_return(nil)
      expect(subject.current_state).to eq('missing')
    end

    it 'returns running if container is running' do
      container = double(:container, :running? => true)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.current_state).to eq('running')
    end

    it 'returns restarting if container is restarting' do
      container = double(:container, :running? => false, :restarting? => true)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.current_state).to eq('restarting')
    end

    it 'returns stopped if container is not running or restarting' do
      container = double(:container, :running? => false, :restarting? => false)
      allow(subject.wrapped_object).to receive(:get_container).and_return(container)
      expect(subject.current_state).to eq('stopped')
    end
  end
end
