module Game
  module Display; end
  module Input; end
  module ThreeD; end
  module Save
    def self.supported?; true; end
    def self.write(_slot, value); @data = value; true; end
    def self.read(_slot); @data; end
  end
end
source = File.read(File.join(__dir__, 'main.rb'))
eval(source.sub("require 'game'", '').sub("TinyBlocks.run\n", ''), TOPLEVEL_BINDING)
TinyBlocks.reset
TinyBlocks.set(3, 1, 1, 13)
TinyBlocks.set(2, 1, 2, 7)
raise 'save failed' unless TinyBlocks.save_world
TinyBlocks.reset
raise 'load failed' unless TinyBlocks.load_world
raise 'blocks not restored' unless TinyBlocks.get(3, 1, 1) == 13 && TinyBlocks.get(2, 1, 2) == 7
raise 'spawn obstructed' unless TinyBlocks.free?(3.5, 1.5, TinyBlocks.instance_variable_get(:@feet))
legacy = Array.new(8 * 8 * 4, 0)
64.times { |i| legacy[i] = 1 }
legacy[64 + 2 * 8 + 2] = 7
Game::Save.write('tiny_blocks', 'TB1|' + legacy.join(','))
raise 'legacy load failed' unless TinyBlocks.load_world
raise 'legacy blocks missing' unless TinyBlocks.get(2, 1, 2) == 7
raise 'new layers not empty' unless TinyBlocks.get(2, 7, 2) == 0
Game::Save.write('tiny_blocks', 'TB1|1,2,invalid')
raise 'invalid save accepted' if TinyBlocks.load_world
raise 'invalid save changed world' unless TinyBlocks.get(2, 1, 2) == 7
puts 'Save, load, safe spawn and invalid data passed.'
