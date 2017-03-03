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
      notify_lb_remove if self.grid_service.linked_to_load_balancer?
      self.grid_service.destroy
      nodes.each do |node|
        notify_node(node) if node
      end
    end

    # @param [HostNode] node
    def notify_node(node)
      RpcClient.new(node.node_id).notify('/service_pods/notify_update', 'terminate')
    end

    def notify_lb_remove
      lb = self.grid_service.linked_to_load_balancers[0]
      return unless lb
      node = self.grid_service.grid_service_instances.select{ |i| i.host_node.connected? }
      return unless node

      lb_name = lb.qualified_name
      service_name = service.name_with_stack
      if node
        RpcClient.new(node.node_id).request('/load_balancers/remove_service', lb_name, service_name)
      end
    end
  end
end
