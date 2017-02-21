class Node

  attr_reader :id,
              :created_at,
              :updated_at,
              :name,
              :labels,
              :peer_ips,
              :node_number,
              :initial_member,
              :grid

  # @param [Hash] data
  def initialize(data)
    @id = data['id']
    @created_at = data['created_at']
    @updated_at = data['updated_at']
    @name = data['name']
    @labels = data['labels']
    @peer_ips = data['peer_ips']
    @node_number = data['node_number']
    @initial_member = data['initial_member']
    @grid = data['grid']
  end

  def statsd_conf
    grid.dig('stats', 'statsd') || {}
  end
end
