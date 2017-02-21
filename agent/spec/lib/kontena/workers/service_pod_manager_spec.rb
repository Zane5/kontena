require_relative '../../../spec_helper'

describe Kontena::Workers::ServicePodManager do
  include RpcClientMocks

  let(:subject) { described_class.new(false) }
  let(:node) do
    Node.new(
      'id' => 'aaaa',
      'instance_number' => 2,
      'grid' => {}
    )
  end

  before(:each) { Celluloid.boot }
  after(:each) { Celluloid.shutdown }

  describe '#initialize' do
    it 'starts to listen service_pod:update events' do
      subject = described_class.new(false)
      expect(subject.wrapped_object).to receive(:on_update_notify).once
      Celluloid::Notifications.publish('service_pod:update', 'foo')
      sleep 0.1
    end
  end

  describe '#populate_workers_from_master' do
    before(:each) do
      mock_rpc_client
      allow(subject.wrapped_object).to receive(:node).and_return(node)
      allow(subject.wrapped_object).to receive(:ensure_service_worker)
    end

    it 'calls terminate_workers' do
      allow(rpc_client).to receive(:request).with('/node_service_pods/list', [node.id]).and_return(
        rpc_future(
          {
            'service_pods' => [
              { 'id' => 'a/1', 'instance_number' => 1}
            ]
          }
        )
      )
      expect(subject.wrapped_object).to receive(:terminate_workers).with(['a/1'])
      subject.populate_workers_from_master
    end

    it 'does not call terminate_workers if master does not return service pods' do
      allow(rpc_client).to receive(:request).with('/node_service_pods/list', [node.id]).and_return(
        rpc_future(
          {
            'error' => 'oh no'
          }
        )
      )
      expect(subject.wrapped_object).not_to receive(:terminate_workers)
      subject.populate_workers_from_master
    end

    it 'calls ensure_service_worker for each service pod' do
      allow(rpc_client).to receive(:request).with('/node_service_pods/list', [node.id]).and_return(
        rpc_future(
          {
            'service_pods' => [
              { 'id' => 'a/1', 'instance_number' => 1},
              { 'id' => 'b/2', 'instance_number' => 2}
            ]
          }
        )
      )
      expect(subject.wrapped_object).to receive(:ensure_service_worker) do |s|
        expect(s.id).to eq('a/1')
      end
      expect(subject.wrapped_object).to receive(:ensure_service_worker) do |s|
        expect(s.id).to eq('b/2')
      end
      subject.populate_workers_from_master
    end
  end

  describe '#populate_workers_from_docker' do
    let(:connection) { spy(:docker_connection) }
    before(:each) do
      allow(Docker).to receive(:connection).and_return(connection)
    end

    it 'calls ensure_service_worker for each container' do
      allow(connection).to receive(:get).with('/containers/json', anything).and_return([
        {'id' => 'aaa'},
        {'id' => 'bbb'}
      ])
      expect(subject.wrapped_object).to receive(:ensure_service_worker).twice
      subject.populate_workers_from_docker
    end
  end

  describe '#terminate_workers' do
    it 'terminates workers that are not included in passed array' do
      workers = {
        'a/1' => Kontena::Workers::ServicePodWorker.new(node),
        'b/3' => Kontena::Workers::ServicePodWorker.new(node)
      }
      allow(subject.wrapped_object).to receive(:workers).and_return(workers)
      expect(workers['a/1'].wrapped_object).to receive(:destroy).once
      expect(workers['b/3'].wrapped_object).not_to receive(:destroy)
      subject.terminate_workers(['b/3'])
      sleep 0.01
    end
  end

  describe '#finalize' do
    it 'terminates all workers' do
      workers = {
        'a/1' => Kontena::Workers::ServicePodWorker.new(node),
        'b/3' => Kontena::Workers::ServicePodWorker.new(node)
      }
      allow(subject.wrapped_object).to receive(:workers).and_return(workers)
      subject.finalize
      expect(workers.all?{|id, w| !w.alive?}).to be_truthy
    end
  end
end
