require 'chunky_png'

# 'pref' is the drawing preference when overlapping, the lower the better
# 'att' is the number of attributes they have, for parsing old format
# 'old' is the ID in the old format, '-1' if it didn't exist
OBJECTS = {
  0x00 => {name: 'ninja', pref: 4, att: 2, old: 0},
  0x01 => {name: 'mine', pref: 22, att: 2, old: 1},
  0x02 => {name: 'gold', pref: 21, att: 2, old: 2},
  0x03 => {name: 'exit', pref: 25, att: 4, old: 3},
  0x04 => {name: 'exit switch', pref: 20, att: 0, old: -1},
  0x05 => {name: 'regular door', pref: 19, att: 2, old: 4},
  0x06 => {name: 'locked door', pref: 28, att: 5, old: 5},
  0x07 => {name: 'locked door switch', pref: 27, att: 0, old: -1},
  0x08 => {name: 'trap door', pref: 29, att: 5, old: 6},
  0x09 => {name: 'trap door switch', pref: 26, att: 0, old: -1},
  0x0A => {name: 'launch pad', pref: 18, att: 4, old: 7},
  0x0B => {name: 'one-way platform', pref: 24, att: 3, old: 8},
  0x0C => {name: 'chaingun drone', pref: 16, att: 4, old: 9},
  0x0D => {name: 'laser drone', pref: 17, att: 4, old: 10},
  0x0E => {name: 'zap drone', pref: 15, att: 4, old: 11},
  0x0F => {name: 'chase drone', pref: 14, att: 4, old: 12},
  0x10 => {name: 'floor guard', pref: 13, att: 2, old: 13},
  0x11 => {name: 'bounce block', pref: 3, att: 2, old: 14},
  0x12 => {name: 'rocket', pref: 8, att: 2, old: 15},
  0x13 => {name: 'gauss turret', pref: 9, att: 2, old: 16},
  0x14 => {name: 'thwump', pref: 6, att: 3, old: 17},
  0x15 => {name: 'toggle mine', pref: 23, att: 2, old: 18},
  0x16 => {name: 'evil ninja', pref: 5, att: 2, old: 19},
  0x17 => {name: 'laser turret', pref: 7, att: 4, old: 20},
  0x18 => {name: 'boost pad', pref: 1, att: 2, old: 21},
  0x19 => {name: 'deathball', pref: 10, att: 2, old: 22},
  0x1A => {name: 'micro drone', pref: 12, att: 4, old: 23},
  0x1B => {name: 'alt deathball', pref: 11, att: 2, old: 24},
  0x1C => {name: 'shove thwump', pref: 2, att: 2, old: 25}
}
ROWS = 23
COLUMNS = 42
DIM = 44
WIDTH = DIM * (COLUMNS + 2)
HEIGHT = DIM * (ROWS + 2)
COLOR = ChunkyPNG::Color.rgb(140,148,135)

# for hex to dec conversion
class String
  def hd
    self.unpack('H*')[0].to_i(16)
  end
end

# for padding arrays
class Array
  def rjust(n, x); Array.new([0, n-length].max, x)+self end
  def ljust(n, x); dup.fill(x, length...n) end
end

# new - current map format, used by userlevels, attract files...
# old - old map format, used by Metanet levels
def parse_map(data: "", type: "new")
  if data.empty? then return end
  if type == "level" || type == "attract" then type = "new" end
  case type
  when "new"
    tiles = data[0..965].split(//).map{ |b| b.hd }.each_slice(COLUMNS).to_a
    object_counts = data[966..1045].scan(/../).map{ |s| s.reverse.hd }
    objects = data[1046..-1].scan(/.{5}/m).map{ |o| o.chars.map{ |e| e.hd } }
  when "old"
    data = data[8..-1]
    tiles = data[0..1931].scan(/../).map{ |b| b.reverse.to_i(16) }.each_slice(COLUMNS).to_a
    objs = data[1932..-1]
    objects = []
    OBJECTS.sort_by{ |id, o| o[:old] }.reject{ |id, o| o[:old] == -1 }.each{ |id, type|
      if objs.length < 4 then break end
      quantity = objs[0..3].scan(/../).map(&:reverse).join.to_i(16)
      objs[4 .. 3 + 2 * quantity * type[:att]].scan(/.{#{2 * type[:att]}}/).each{ |o|
        if ![3,6,8].include?(id) # everything else
          objects << [id] + o.scan(/../).map{ |att| att.reverse.to_i(16) }.ljust(4,0)
        else # door switches
          atts = o.scan(/../).map{ |att| att.reverse.to_i(16) }
          objects << [id] + atts[0..-3].ljust(4,0)  # door
          objects << [id + 1] + atts[-2..-1].ljust(4,0) # switch
        end
      }
      objs = objs[4 + 2 * quantity * type[:att]..-1]
    };0
  end
  {tiles: tiles, objects: objects}
end

# level - for files returned by the level editor (stored in "N++/levels")
# attract -  for death replay files (stored in "N++/attract")
# old - for files with Metanet levels (old format)
def parse_file(filename: "", type: "level")
  !filename.empty? ? file = File.binread(filename) : return
  case type
  when "level"
    mode = file[12].reverse.hd # game mode: 0 = solo, 1 = coop, 2 = race, 4 = unset
    title = file[38..165].split(//).delete_if{ |b| b == "\x00" }.join
    author = ""
    map = parse_map(data: file[184..-1], type: "new")
  when "attract"
    map_length = file[0..3].reverse.hd
    demo_length = file[4..7].reverse.hd
    map_data = file[8 .. 8 + map_length - 1]
    demo_data = file[8 + map_length .. 8 + map_length + demo_length - 1]

    level_id = map_data[0..3].reverse.hd
    title = map_data[30..157].split(//).delete_if{ |b| b == "\x00" }.join
    index = map_data[159..-1].split(//).find_index("\x00") + 158
    author = map_data[159..index]
    map = parse_map(data: map_data[index + 2..-1], type: "new")
    # demo = parse_demo(data: demo_data, attract: true) # no se si el attract hace falta, comparar esto con una replay normal
  when "old"
    title = file.split('#')[0][1..-1]
    author = "Metanet Software"
    map = parse_map(data: file.split("#")[1], type: "old")
  else
    print("ERROR: Incorrect type (level, attract, old).")
    return 0
  end
  {title: title, author: author, tiles: map[:tiles], objects: map[:objects]}
end

def coord(n) # transform N++ coordinates into pixel coordinates
  DIM * n.to_f / 4
end

def check_dimensions(image, x, y) # ensure image is within limits
  x >= 0 && y >= 0 && x <= WIDTH - image.width && y <= HEIGHT - image.height
end

# TODO: For diagonals, I can't rotate 45º, so get new pictures or new library
def generate_image(data: "", input: "", output: "image", type: :level)
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
  if !input.empty?
    map = parse_file(filename: input, type: type)
  elsif !data.empty?
    map = parse_map(data: data, type: type)
  else
    print("ERROR: Introduce either an 'input' filename or map 'data'.")
  end
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
