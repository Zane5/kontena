require_relative '../models/node'

module Kontena
  module Rpc
    class LbApi

      # @param [Hash] data
      def remove_service(lb_name, service_name)
        Celluloid::Actor[:lb_configurer].remove_config(lb_name, service_name)
        {}
      end
    end
  end
end
