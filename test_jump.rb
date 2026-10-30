# Run with host Ruby: ruby test_jump.rb
module Game
  module Display; end
  module Input; end
  module ThreeD; end
end
source = File.read(File.join(__dir__, 'main.rb'))
eval(source.sub("require 'game'", '').sub("TinyBlocks.run\n", ''), TOPLEVEL_BINDING)

[0.033, 0.1].each do |dt|
  TinyBlocks.reset
  TinyBlocks.set(3, 1, 3, 2)
  TinyBlocks.instance_variable_set(:@z, 2.72)
  TinyBlocks.instance_variable_set(:@vertical_speed, 7.4)
  peak = 1.0
  30.times do
    TinyBlocks.update_height(dt)
    feet = TinyBlocks.instance_variable_get(:@feet)
    peak = feet if feet > peak
    z = TinyBlocks.instance_variable_get(:@z)
    next_z = z + 2.2 * dt
    TinyBlocks.instance_variable_set(:@z, next_z) if z < 3.5 && TinyBlocks.free?(3.5, next_z, feet)
  end
  raise "jump too low at dt=#{dt}: #{peak}" unless peak > 2.0
  raise "failed to land on block at dt=#{dt}" unless TinyBlocks.instance_variable_get(:@feet) == 2.0 && TinyBlocks.instance_variable_get(:@grounded)
end
puts 'Jump and landing passed at 30 fps and 10 fps.'
