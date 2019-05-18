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

class String
  def hd # hex string to dec
    self.unpack('H*')[0].to_i(16)
  end
end

def coord(n)
  44 * ((n - 4).to_f) / 4
end

def parse_map(data: "", filename: nil)
  file = !filename.nil? ? File.binread(filename) : data
  size = file[4..7].reverse.hd # filesize
  mode = file[12].reverse.hd # game mode: 0 = solo, 1 = coop, 2 = race, 4 = unset
  title = file[38..165].split(//).delete_if{ |b| b == "\x00" }.join # map title
  tiles = file[184..1149].split(//).map{ |b| b.hd }.each_slice(42).to_a # tile data
  object_counts = file[1150..1229].scan(/../).map{ |s| s.reverse.hd } # object counts ordered by ID
  objects = file[1230..-1].scan(/.{5}/m).map{ |o| o.chars.map{ |e| e.hd } } # object data ordered by ID
  {tiles: tiles, objects: objects}
end

def parse_attract(data: "", filename: nil)
  file = !filename.nil? ? File.binread(filename) : attract
  $map_length = file[0..3].reverse.hd
  $demo_length = file[4..7].reverse.hd
  $map_data = file[8 .. 8 + $map_length - 1]
  $demo_data = file[8 + $map_length .. 8 + $map_length + $demo_length - 1]
  return true
end

# TODO: For diagonals, I can't rotate 45º, so get new pictures or new library
# TODO: Sort objects so that the order in which they overlap coincides with N++ (e.g. bounce block should be the last one, probably)
def generate_image(input: "orientation", output: "image")
  tile = {}
  object = {}
  tile_images = Dir.entries("images/tiles").reject{ |f| f == "." || f == ".." }
  object_images = Dir.entries("images/objects").reject{ |f| f == "." || f == ".." }
  tile_images.each do |i|
    tile[i[0..-5].to_i(16)] = ChunkyPNG::Image.from_file("images/tiles/" + i)
  end
  object_images.each do |i|
    object[i[0..-5].to_i(16)] = ChunkyPNG::Image.from_file("images/objects/" + i)
  end
  image = ChunkyPNG::Image.new(1848, 1012, ChunkyPNG::Color.rgb(140,148,135))
  map = parse_map(filename: input)
  tiles = map[:tiles]
  objects = map[:objects]
  tiles.each_with_index do |slice, row|
    slice.each_with_index do |t, column|
      if t == 0 || t == 1 # empty and full tiles
        new_tile = tile[t]
      elsif t >= 2 && t <= 17 # half tiles and curved slopes
        new_tile = tile[t - (t - 2) % 4]
        (1 .. (t - 2) % 4).each{ |i| new_tile = new_tile.rotate_clockwise }
      elsif t >= 18 && t <= 33 # small and big straight slopes
        new_tile = tile[t - (t - 2) % 4]
        if (t - 2) % 4 >= 2 then new_tile = new_tile.flip_horizontally end
        if (t - 2) % 4 == 1 || (t - 2) % 4 == 2 then new_tile = new_tile.flip_vertically end
      end
      image.compose!(new_tile, 44 * column, 44 * row)
    end
  end
  objects.each do |o|
    new_object = object[o[0]]
    (1 .. o[3] / 2).each{ |i| new_object = new_object.rotate_clockwise }
    image.compose!(new_object, coord(o[1]) - new_object.width / 2, coord(o[2]) - new_object.height / 2)
  end
  image.save(output + ".png")
end
