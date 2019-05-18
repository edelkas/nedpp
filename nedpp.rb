require 'chunky_png'

OBJECTS = {
  0x00 => 'ninja',
  0x01 => 'mine',
  0x02 => 'gold',
  0x03 => 'exit',
  0x04 => 'exit switch',
  0x05 => 'regular door',
  0x06 => 'locked door',
  0x07 => 'locked door switch',
  0x08 => 'trap door',
  0x09 => 'trap door switch',
  0x0A => 'launch pad',
  0x0B => 'one-way platform',
  0x0C => 'chaingun drone',
  0x0D => 'laser drone',
  0x0E => 'zap drone',
  0x0F => 'chase drone',
  0x10 => 'floor guard',
  0x11 => 'bounce block',
  0x12 => 'rocket',
  0x13 => 'gauss turret',
  0x14 => 'thwump',
  0x15 => 'toggle mine',
  0x16 => 'evil ninja',
  0x17 => 'laser turret',
  0x18 => 'boost pad',
  0x19 => 'deathball',
  0x1A => 'micro drone',
  0x1B => 'alt deathball',
  0x1C => 'shove thwump'
}

# Note: Map data header is different in "levels" files and "attract" files

def parse_map(data: "", filename: nil)
  file = !filename.nil? ? File.binread(filename) : data
  magic_number = file[0..3].reverse.unpack('H*')[0].to_i(16)
  size = file[4..7].reverse.unpack('H*')[0].to_i(16) # filesize
  mode = file[12].reverse.unpack('H*')[0].to_i(16) # game mode: 0 = solo, 1 = coop, 2 = race, 4 = unset
  title = file[38..165].split(//).delete_if{ |b| b == "\x00" }.join # map title
  tiles = file[184..1149].split(//).map{ |b| b.unpack('H*')[0].to_i(16) }.each_slice(42).to_a # tile data
  object_counts = file[1150..1229].scan(/../).map{ |s| s.reverse.unpack('H*')[0].to_i(16) } # object counts ordered by ID
  objects = file[1230..-1].scan(/.{5}/).map{ |o|
    [o[0].unpack('H*')[0].to_i(16), o[1].unpack('H*')[0].to_i(16), o[2].unpack('H*')[0].to_i(16), o[3].unpack('H*')[0].to_i(16), o[4].unpack('H*')[0].to_i(16)]
  } # object data ordered by ID
  {tiles: tiles, objects: objects}
end

def parse_attract(data: "", filename: nil)
  file = !filename.nil? ? File.binread(filename) : attract
  $map_length = file[0..3].reverse.unpack('H*')[0].to_i(16)
  $demo_length = file[4..7].reverse.unpack('H*')[0].to_i(16)
  $map_data = file[8 .. 8 + $map_length - 1]
  $demo_data = file[8 + $map_length .. 8 + $map_length + $demo_length - 1]
  return true
end

def create_image(input: "tile_test", output: "image")
  tile = {}
  tile_images = Dir.entries("images").reject{ |f| f == "." || f == ".." }
  tile_images.each do |i|
    tile[i[0..-5].to_i(16)] = ChunkyPNG::Image.from_file("images/" + i)
  end
  image = ChunkyPNG::Image.new(1848, 1012, ChunkyPNG::Color('white'))
  map = parse_map(filename: input)
  tiles = map[:tiles]
  objects = map[:objects]
  tiles.each_with_index do |slice, row|
    slice.each_with_index do |t, column|
      if t == 0 || t == 1
        image.compose!(tile[t], 44 * column, 44 * row)
      elsif t >= 2 || t <= 33
        new_tile = tile[t - (t - 2) % 4]
        (1 .. (t - 2) % 4).each{ |i| new_tile.rotate_clockwise! }
        image.compose!(new_tile, 44 * column, 44 * row)
      end
    end
  end
  image.save(output + ".png")
end
