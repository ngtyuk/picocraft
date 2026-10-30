# Generate short mono PCM sound effects for both game backends.
require 'fileutils'
root = File.join(__dir__, 'assets')
FileUtils.mkdir_p(root)
rate = 12000
[['place.wav', 360, 0.09], ['break.wav', 140, 0.13],
 ['jump.wav', 520, 0.10], ['select.wav', 760, 0.06]].each do |name, frequency, duration|
  count = (rate * duration).to_i
  samples = Array.new(count) do |i|
    envelope = (count - i).to_f / count
    (128 + Math.sin(i * frequency * 2 * Math::PI / rate) * 55 * envelope).to_i
  end.pack('C*')
  header = 'RIFF' + [36 + samples.bytesize].pack('V') + 'WAVEfmt ' +
           [16, 1, 1, rate, rate, 1, 8].pack('VvvVVvv') +
           'data' + [samples.bytesize].pack('V')
  File.binwrite(File.join(root, name), header + samples)
end
