require_relative 'service_pod_worker'
require_relative '../models/service_pod'

module Kontena::Workers
  class ServicePodManager
    include Celluloid
    include Celluloid::Notifications
    include Kontena::Logging
    include Kontena::Helpers::RpcHelper

    attr_reader :workers

    finalizer :finalize

    def initialize(autostart = true)
      @workers = {}
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
      if @node.nil?
        @node = Actor[:node_info_worker].node
      end

      @node
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
      filters = JSON.dump({
        label: [
            "io.kontena.container.type=container",
        ]
      })
      Docker::Container.all(all: true, filters: filters).each do |c|
        service_pod = Kontena::Models::ServicePod.new(
          'id' => "#{c.service_id}/#{c.instance_number}",
          'service_id' => c.service_id,
          'instance_number' => c.instance_number,
          'desired_state' => "unknown"
        )
        ensure_service_worker(service_pod)
      end
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
      retries = 0
      begin
        unless workers[service_pod.id]
          workers[service_pod.id] = ServicePodWorker.new(node)
        end
        workers[service_pod.id].async.update(service_pod)
      rescue Celluloid::DeadActorError => exc
        workers.delete(service_pod.id)
        if retries == 1
          retry
        else
          error exc.message
        end
      end
    end

    def finalize
      workers.each do |k, w|
        w.terminate if w.alive?
      end
    end
  end
end
