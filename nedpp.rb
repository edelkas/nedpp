require 'chunky_png'

OBJECTS = { # 'pref' is the drawing preference when overlapping, the lower the better
  0x00 => {name: 'ninja', pref: 4},
  0x01 => {name: 'mine', pref: 22},
  0x02 => {name: 'gold', pref: 21},
  0x03 => {name: 'exit', pref: 25},
  0x04 => {name: 'exit switch', pref: 20},
  0x05 => {name: 'regular door', pref: 19},
  0x06 => {name: 'locked door', pref: 28},
  0x07 => {name: 'locked door switch', pref: 27},
  0x08 => {name: 'trap door', pref: 29},
  0x09 => {name: 'trap door switch', pref: 26},
  0x0A => {name: 'launch pad', pref: 18},
  0x0B => {name: 'one-way platform', pref: 24},
  0x0C => {name: 'chaingun drone', pref: 16},
  0x0D => {name: 'laser drone', pref: 17},
  0x0E => {name: 'zap drone', pref: 15},
  0x0F => {name: 'chase drone', pref: 14},
  0x10 => {name: 'floor guard', pref: 13},
  0x11 => {name: 'bounce block', pref: 3},
  0x12 => {name: 'rocket', pref: 8},
  0x13 => {name: 'gauss turret', pref: 9},
  0x14 => {name: 'thwump', pref: 6},
  0x15 => {name: 'toggle mine', pref: 23},
  0x16 => {name: 'evil ninja', pref: 5},
  0x17 => {name: 'laser turret', pref: 7},
  0x18 => {name: 'boost pad', pref: 1},
  0x19 => {name: 'deathball', pref: 10},
  0x1A => {name: 'micro drone', pref: 12},
  0x1B => {name: 'alt deathball', pref: 11},
  0x1C => {name: 'shove thwump', pref: 2}
}
ROWS = 23
COLUMNS = 42
DIM = 44
WIDTH = DIM * (COLUMNS + 2)
HEIGHT = DIM * (ROWS + 2)
COLOR = ChunkyPNG::Color.rgb(140,148,135)

class String
  def hd # hex string to dec
    self.unpack('H*')[0].to_i(16)
  end
end

def quantity(s)
  s.scan(/../).map{ |b| b.reverse }.join.to_i(16)
end

# Note: Map data header is different in "level" files and "attract" files
def parse_map(data: "", filename: nil, type: :level)
  file = !filename.nil? ? File.binread(filename) : data
  case type
  when :level
    mode = file[12].reverse.hd # game mode: 0 = solo, 1 = coop, 2 = race, 4 = unset
    title = file[38..165].split(//).delete_if{ |b| b == "\x00" }.join
    index = 182
    author = ""
  when :attract
    level_id = file[0..3].reverse.hd
    title = file[30..157].split(//).delete_if{ |b| b == "\x00" }.join
    index = file[159..-1].split(//).find_index("\x00") + 158
    author = file[159..index]
  when :old
    title = file.split('#')[0][1..-1]
    map = file.split("#")[1][8..-1]
    tiles = map[0..1931].scan(/../).map{ |b| b.reverse.to_i(16) }
    objects = map[1932..-1]
    ninja_count = quantity(objects[0..3])
    ninja = objects[4..7].scan(/.{4}/).map{ |g| g.scan(/../).map{ |b| b.reverse.to_i(16) } }
  end
  tiles = file[index + 2 .. index + 967].split(//).map{ |b| b.hd }.each_slice(COLUMNS).to_a # tile data
  object_counts = file[index + 968 .. index + 1047].scan(/../).map{ |s| s.reverse.hd } # object counts ordered by ID
  objects = file[index + 1048 .. -1].scan(/.{5}/m).map{ |o| o.chars.map{ |e| e.hd } } # object data ordered by ID
  {title: title, author: author, tiles: tiles, objects: objects}
end

def parse_attract(data: "", filename: nil)
  file = !filename.nil? ? File.binread(filename) : attract
  map_length = file[0..3].reverse.hd
  demo_length = file[4..7].reverse.hd
  map_data = file[8 .. 8 + map_length - 1]
  demo_data = file[8 + map_length .. 8 + map_length + demo_length - 1]
  map = parse_map(data: map_data, type: :attract)
  # demo = parse_demo(data: demo_data, attract: true) # no se si el attract hace falta, comparar esto con una replay normal
  {title: map[:title], author: map[:author], tiles: map[:tiles], objects: map[:objects]}
end

def coord(n) # transform N++ coordinates into pixel coordinates
  DIM * n.to_f / 4
end

def check_dimensions(image, x, y) # ensure image is within limits
  x >= 0 && y >= 0 && x <= WIDTH - image.width && y <= HEIGHT - image.height
end

# TODO: For diagonals, I can't rotate 45º, so get new pictures or new library
def generate_image(data: "", input: "orientation", output: "image", attract: false)
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
  image = ChunkyPNG::Image.new(WIDTH, HEIGHT, COLOR)
  map = attract ? parse_attract(data: "", filename: input) : parse_map(data: "", filename: input)
  tiles = map[:tiles]
  objects = map[:objects].sort_by{ |o| -OBJECTS[o[0]][:pref] }
  objects.each do |o| # paint objects
    new_object = object[o[0]]
    (1 .. o[3] / 2).each{ |i| new_object = new_object.rotate_clockwise }
    if check_dimensions(new_object, coord(o[1]) - new_object.width / 2, coord(o[2]) - new_object.height / 2)
      image.compose!(new_object, coord(o[1]) - new_object.width / 2, coord(o[2]) - new_object.height / 2)
    end
  end
  (0 .. COLUMNS + 1).each do |t| # paint borders
    if t <= ROWS
      image.compose!(tile[1], 0, DIM * t)
      image.compose!(tile[1], DIM * (COLUMNS + 1), DIM * t)
    end
    image.compose!(tile[1], DIM * t, 0)
    image.compose!(tile[1], DIM * t, DIM * (ROWS + 1))
  end
  tiles.each_with_index do |slice, row| # paint tiles
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
      image.compose!(new_tile, DIM + DIM * column, DIM + DIM * row)
    end
  end
  image.save(output + ".png")
end
