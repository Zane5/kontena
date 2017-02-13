require_relative '../../spec_helper'

describe Volumes::Create do

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  let! :stack do
    grid.stacks.create!(
      name: 'teststack',
    )
  end

  describe '#run' do
    it 'creates new volume' do
      expect {
        outcome = Volumes::Create.run(
          grid: grid,
          stack: stack,
          name: 'foo',
          scope: 'node'
        )
        expect(outcome.success?).to be_truthy
      }.to change {stack.volumes.count}. by 1
    end


  end

end
