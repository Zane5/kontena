module GridServices
  class Delete < Mutations::Command
    include Workers

    required do
      model :grid_service
    end

    def validate
      linked_from_services = self.grid_service.linked_from_services
      if linked_from_services.count > 0
        add_error(:service, :invalid, "Cannot delete service that is linked to another service (#{linked_from_services.map{|s| s.name}.join(', ')})")
      end
    end

    def execute
      nodes = self.grid_service.grid_service_instances.map{ |i| i.host_node }
      self.grid_service.destroy
      nodes.each do |node|
        notify_node(node) if node
      end
    end

    def notify_node(node)
      RpcClient.new(node.node_id).notify('/service_pods/notify_update', 'terminate')
    end
  end
end
