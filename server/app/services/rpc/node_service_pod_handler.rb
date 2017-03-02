module Rpc
  class NodeServicePodHandler
    include Celluloid

    def initialize(grid)
      @grid = grid
    end

    # @param [String] id
    # @return [Array<Hash>]
    def list(id)
      node = @grid.host_nodes.find_by(node_id: id)
      return { error: 'Node not found' } unless node
      service_pods = node.grid_service_instances.includes(:grid_service).map { |i|
        ServicePodSerializer.new(i).to_hash
      }

      { service_pods: service_pods }
    end

    def set_state(id, pod)
      node = @grid.host_nodes.find_by(node_id: id)
      return unless node
      service_instance = node.grid_service_instances.find_by(
        grid_service_id: pod['service_id'], instance_number: pod['instance_number']
      )
      service_instance.set(state: pod['state']) if service_instance
    end
  end
end