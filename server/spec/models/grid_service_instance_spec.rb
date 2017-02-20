require_relative '../spec_helper'

describe GridServiceInstance do
  it { should have_fields(:desired_state, :state, :deploy_rev).of_type(String) }
  it { should have_fields(:instance_number).of_type(Integer) }

  it { should belong_to(:grid_service) }
  it { should belong_to(:host_node) }
end
