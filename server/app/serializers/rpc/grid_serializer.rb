require_relative '../rpc_serializer'

module Rpc
  class GridSerializer < RpcSerializer
    attribute :id
    attribute :name
    attribute :initial_size
    attribute :trusted_subnets

    def id
      object.to_path
    end
  end
end
