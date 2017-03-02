require_relative 'service_pod_worker'
require_relative '../models/service_pod'

module Kontena::Workers
  class ServicePodManager
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    attr_reader :workers

    trap_exit :on_worker_exit
    finalizer :finalize

    def initialize(autostart = true)
      @workers = {}
      subscribe('agent:node_info', :on_node_info)
      subscribe('service_pod:update', :on_update_notify)
      async.start if autostart
    end

    def start
      node # blocks until it's available
      populate_workers_from_docker
      loop do
        populate_workers_from_master
        sleep 30
      end
    end

    # @return [Node]
    def node
      while @node.nil?
        @node = Actor[:node_info_worker].node
        sleep 0.1 if @node.nil?
      end

      @node
    end

    # @param [String] topic
    # @param [Node] node
    def on_node_info(topic, node)
      @node = node
    end

    def on_update_notify(_, _)
      populate_workers_from_master
    end

    def populate_workers_from_master
      exclusive {
        request = rpc_client.request("/node_service_pods/list", [node.id])
        response = request.value
        return unless response['service_pods'].is_a?(Array)

        service_pods = response['service_pods']
        current_ids = service_pods.map { |p| p['id'] }
        terminate_workers(current_ids)

        service_pods.each do |s|
          ensure_service_worker(Kontena::Models::ServicePod.new(s))
        end
      }
    end

    def populate_workers_from_docker
      info "populating service pod workers from docker"
      fetch_containers.each do |c|
        service_pod = Kontena::Models::ServicePod.new(
          'id' => "#{c.service_id}/#{c.instance_number}",
          'service_id' => c.service_id,
          'instance_number' => c.instance_number,
          'desired_state' => "unknown"
        )
        ensure_service_worker(service_pod)
      end
    end

    # @return [Array<Docker::Container>]
    def fetch_containers
      filters = JSON.dump({
        label: [
            "io.kontena.container.type=container",
        ]
      })
      Docker::Container.all(all: true, filters: filters)
    end

    # @param [Array<String>] current_ids
    def terminate_workers(current_ids)
      workers.keys.each do |id|
        unless current_ids.include?(id)
          begin
            workers[id].async.destroy
          rescue Celluloid::DeadActorError
            workers.delete(id)
          end
        end
      end
    end

    # @param [ServicePod] service_pod
    def ensure_service_worker(service_pod)
      begin
        unless workers[service_pod.id]
          worker = ServicePodWorker.new(node)
          self.link worker
          workers[service_pod.id] = worker
        end
        workers[service_pod.id].async.update(service_pod)
      rescue Celluloid::DeadActorError => exc
        workers.delete(service_pod.id)
      end
    end

    def on_worker_exit(worker, reason)
      workers.delete_if { |k, w| w == worker }
    end

    def finalize
      workers.each do |k, w|
        w.terminate if w.alive?
      end
    end
  end
end