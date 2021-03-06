################################################################################
#                                   Ned++
# @desc: A work in progress, third party tool for N++, with the following goals:
#
# 1) PARSE levels from a multitude of different formats.
# 2) SAVE levels into a multitude of different formats.
# 3) CONVERT between a multitude of different formats.
# 4) PREVIEW levels by generating screenshots in any palette.
# 5) CREATE or EDIT levels.
# 6) Perform N-ART (e.g. image to map).
# 7) Manual demo builder.
# 8) Etc. (suggestions?).
#
# @author: Eddy.
# @date: 2020-02-01.
#
################################################################################

require 'chunky_png'
include ChunkyPNG::Color

# <---------------------------------------------------------------------------->
#                                  CONSTANTS
# <---------------------------------------------------------------------------->

# 'pref' is the drawing preference when for overlaps, the lower the better
# 'att' is the number of attributes they have in the old format (in the new one it's always 5)
# 'old' is the ID in the old format, '-1' if it didn't exist
# 'pal' is the index at which the colors of the object start in the palette image
OBJECTS = {
  0x00 => {name: 'ninja',              pref:  4, att: 2, old:  0, pal:  6},
  0x01 => {name: 'mine',               pref: 22, att: 2, old:  1, pal: 10},
  0x02 => {name: 'gold',               pref: 21, att: 2, old:  2, pal: 14},
  0x03 => {name: 'exit',               pref: 25, att: 4, old:  3, pal: 17},
  0x04 => {name: 'exit switch',        pref: 20, att: 0, old: -1, pal: 25},
  0x05 => {name: 'regular door',       pref: 19, att: 3, old:  4, pal: 30},
  0x06 => {name: 'locked door',        pref: 28, att: 5, old:  5, pal: 31},
  0x07 => {name: 'locked door switch', pref: 27, att: 0, old: -1, pal: 33},
  0x08 => {name: 'trap door',          pref: 29, att: 5, old:  6, pal: 39},
  0x09 => {name: 'trap door switch',   pref: 26, att: 0, old: -1, pal: 41},
  0x0A => {name: 'launch pad',         pref: 18, att: 3, old:  7, pal: 47},
  0x0B => {name: 'one-way platform',   pref: 24, att: 3, old:  8, pal: 49},
  0x0C => {name: 'chaingun drone',     pref: 16, att: 4, old:  9, pal: 51},
  0x0D => {name: 'laser drone',        pref: 17, att: 4, old: 10, pal: 53},
  0x0E => {name: 'zap drone',          pref: 15, att: 4, old: 11, pal: 57},
  0x0F => {name: 'chase drone',        pref: 14, att: 4, old: 12, pal: 59},
  0x10 => {name: 'floor guard',        pref: 13, att: 2, old: 13, pal: 61},
  0x11 => {name: 'bounce block',       pref:  3, att: 2, old: 14, pal: 63},
  0x12 => {name: 'rocket',             pref:  8, att: 2, old: 15, pal: 65},
  0x13 => {name: 'gauss turret',       pref:  9, att: 2, old: 16, pal: 69},
  0x14 => {name: 'thwump',             pref:  6, att: 3, old: 17, pal: 74},
  0x15 => {name: 'toggle mine',        pref: 23, att: 2, old: 18, pal: 12},
  0x16 => {name: 'evil ninja',         pref:  5, att: 2, old: 19, pal: 77},
  0x17 => {name: 'laser turret',       pref:  7, att: 4, old: 20, pal: 79},
  0x18 => {name: 'boost pad',          pref:  1, att: 2, old: 21, pal: 81},
  0x19 => {name: 'deathball',          pref: 10, att: 2, old: 22, pal: 83},
  0x1A => {name: 'micro drone',        pref: 12, att: 4, old: 23, pal: 57},
  0x1B => {name: 'alt deathball',      pref: 11, att: 2, old: 24, pal: 86},
  0x1C => {name: 'shove thwump',       pref:  2, att: 2, old: 25, pal: 88}
}
THEMES = ["acid", "airline", "argon", "autumn", "BASIC", "berry", "birthday cake",
  "bloodmoon", "blueprint", "bordeaux", "brink", "cacao", "champagne", "chemical",
  "chococherry", "classic", "clean", "concrete", "console", "cowboy", "dagobah",
  "debugger", "delicate", "desert world", "disassembly", "dorado", "dusk", "elephant",
  "epaper", "epaper invert CUT", "evening", "F7200", "florist", "formal", "galactic",
  "gatecrasher", "gothmode", "grapefrukt", "grappa", "gunmetal", "hazard", "heirloom",
  "holosphere", "hope", "hot", "hyperspace", "ice world", "incorporated", "infographic",
  "invert", "jaune", "juicy", "kicks", "lab", "lava world", "lemonade", "lichen",
  "lightcycle", "line CUT", "m", "machine", "metoro", "midnight", "minus", "mir",
  "mono", "moonbase", "mustard", "mute", "nemk", "neptune", "neutrality", "noctis",
  "oceanographer", "okinami", "orbit", "pale", "papier CUT", "papier invert", "party",
  "petal", "PICO-8", "pinku", "plus", "porphyrous", "poseidon", "powder", "pulse",
  "pumpkin", "QDUST", "quench", "regal", "replicant", "retro", "rust", "sakura",
  "shift", "shock", "simulator", "sinister", "solarized dark", "solarized light",
  "starfighter", "sunset", "supernavy", "synergy", "talisman", "toothpaste", "toxin",
  "TR-808", "tycho CUT", "vasquez", "vectrex", "vintage", "virtual", "vivid", "void",
  "waka", "witchy", "wizard", "wyvern", "xenon", "yeti"]
PALETTE = ChunkyPNG::Image.from_file('palette.png')
BORDERS = "100FF87E1781E0FC3F03C0FC3F03C0FC3F03C078370388FC7F87C0EC1E01C1FE3F13E"
NUMBERS = "3DB7A492E7CFCB3EDE4F9CFF3DFC927DF7FBCF"
NUM_HEIGHT = 5
NUM_WIDTH = 3
ROWS = 23
COLUMNS = 42
DIM = 44
WIDTH = DIM * (COLUMNS + 2)
HEIGHT = DIM * (ROWS + 2)

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

# <---------------------------------------------------------------------------->
#                               PARSING MAPS
# <---------------------------------------------------------------------------->

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
    }
  end
  {tiles: tiles, objects: objects.sort_by{ |o| o[0] }}
rescue
  print("ERROR: Incorrect map data\n")
  return {tiles: [], objects: []}
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

# files with multiple levels on them, probably only makes sense for old format
def parse_multifile(filename: "", type: "old")
  !filename.empty? ? file = File.binread(filename) : return
  case type
  when "old"
    file.split("\n").map(&:strip).reject(&:empty?).map{ |m|
      title = m.split('#')[0][1..-1] rescue ""
      author = "Metanet Software"
      map = parse_map(data: m.split("#")[1], type: "old") rescue {tiles: [], objects: []}
      {title: title, author: author, tiles: map[:tiles], objects: map[:objects]}
    }
  else
    print("ERROR: Incorrect type (old).")
    return 0
  end
end

def parse_folder(input: "", type: "level")
  if input.empty? then input = Dir.pwd end
  if input[-1] != "/" then input = input + "/" end
  Dir.entries(input).select { |f| File.file?(input + f) }.map{ |f| parse_file(filename: input + f, type: type) }
end

def parse_multifolder(input: "", type: "old")
  if input.empty? then input = Dir.pwd end
  if input[-1] != "/" then input = input + "/" end
  Dir.entries(input).select { |f| File.file?(input + f) }.map{ |f|
    [File.basename(input + f, File.extname(input + f)), parse_multifile(filename: input + f, type: type)]
  }.to_h
end

# <---------------------------------------------------------------------------->
#                                SAVING MAPS
# <---------------------------------------------------------------------------->

# locked door and trap door switches are not counted in N++!
def generate_map(tiles: [], objects: [], type: "new")
  case type
  when "new"
    tile_data = tiles.flatten.map{ |b| [b.to_s(16).rjust(2,"0")].pack('H*')[0] }.join
    object_counts = ""
    object_data = ""
    OBJECTS.sort_by{ |id, entity| id }.each{ |id, entity|
      if ![7,9].include?(id) # ignore door switches for counting
        object_counts << objects.select{ |o| o[0] == id }.size.to_s(16).rjust(4,"0").scan(/../).reverse.map{ |b| [b].pack('H*')[0] }.join
      else
        object_counts << "\x00\x00"
      end
      if ![6,7,8,9].include?(id) # doors must once again be treated differently
        object_data << objects.select{ |o| o[0] == id }.map{ |o| o.map{ |b| [b.to_s(16).rjust(2,"0")].pack('H*')[0] }.join }.join
      elsif [6,8].include?(id)
        doors = objects.select{ |o| o[0] == id }.map{ |o| o.map{ |b| [b.to_s(16).rjust(2,"0")].pack('H*')[0] }.join }
        switches = objects.select{ |o| o[0] == id + 1 }.map{ |o| o.map{ |b| [b.to_s(16).rjust(2,"0")].pack('H*')[0] }.join }
        object_data << doors.zip(switches).flatten.join
      end
    }
    map_data = tile_data + object_counts.ljust(80, "\x00") + object_data
  when "old"
    header = "00000000"
    tile_data = tiles.flatten.map{ |t| t.to_s(16).rjust(2,"0").reverse }.join
    objs = objects.map{ |o| o.dup }
    doors_exit = objs.select{ |o| o[0] == 3 }.zip(objs.select{ |o| o[0] == 4 }).map{ |p| [3, p[0][1], p[0][2], p[1][1], p[1][2]] }
    doors_lock = objs.select{ |o| o[0] == 6 }.zip(objs.select{ |o| o[0] == 7 }).map{ |p| [6, p[0][1], p[0][2], p[0][3], p[1][1], p[1][2]] }
    doors_trap = objs.select{ |o| o[0] == 8 }.zip(objs.select{ |o| o[0] == 9 }).map{ |p| [8, p[0][1], p[0][2], p[0][3], p[1][1], p[1][2]] }
    objs = objs.select{ |o| ![3,4,6,7,8,9].include?(o[0]) }.+(doors_exit).+(doors_lock).+(doors_trap).sort_by{ |o| o[0] }
    entities = (0..25).to_a.map{ |id| [id, []] }.to_h
    objs.each{ |o|
      s = o[1..OBJECTS[o[0]][:att]].map{ |a| a.to_s(16).rjust(2, "0").reverse }.join
      entities[OBJECTS[o[0]][:old]].push(s)
    }
    object_data = entities.map{ |k, v| v.size.to_s(16).rjust(4, "0").scan(/../m).map(&:reverse).join + v.join }.join
    footer = "00000000"
    map_data = header + tile_data + object_data + footer
  else
    print("ERROR: Incorrect type (new, old).")
    return 0
  end
  map_data
end

def generate_file(tiles: [], objects: [], demo: [], mode: "solo", title: "Autogen", folder: "", type: "level")
  data = ""
  if folder[-1] != "/" && !folder.empty? then folder = folder + "/" end
  case type
  when "level"
    data = ("\x00" * 4).force_encoding("ascii-8bit") # magic number ?
    data << (1230 + 5 * objects.size).to_s(16).rjust(8,"0").scan(/../).reverse.map{ |b| [b].pack('H*')[0] }.join.force_encoding("ascii-8bit") # filesize
    data << ("\xFF" * 4).force_encoding("ascii-8bit") # static data
    data << (mode == "unset" ? "\x04" : (mode == "race" ? "\x02" : (mode == "coop" ? "\x01" : "\x00"))).force_encoding("ascii-8bit")
    data << ("\x00" * 3 + "\x25" + "\x00" * 3 + "\xFF" * 4 + "\x00" * 14).force_encoding("ascii-8bit") # static data
    data << title[0..126].ljust(128,"\x00").force_encoding("ascii-8bit") # map title
    data << ("\x00" * 18).force_encoding("ascii-8bit") # static data
    data << generate_map(tiles: tiles, objects: objects, type: "new").force_encoding("ascii-8bit") # map data
  when "attract"

  when "old"
    data << "$#{title}#"
    data << generate_map(tiles: tiles, objects: objects, type: "old")
    data << "#"
  else
    print("ERROR: Incorrect type (level, attract, old).")
    return 0
  end
  File.binwrite(folder + title.tr("/", " ").tr("\\", " "), data)
end

def generate_folder(maps: [], folder: "generated maps", mode: "solo", type: "level", indexize: false)
  Dir.mkdir(folder) unless File.exists?(folder)
  padding = Math.log(maps.size,10).to_i + 1
  maps.each_with_index{ |m, i|
    title = indexize ? i.to_s.rjust(padding,"0") + " " + m[:title] : m[:title]
    generate_file(tiles: m[:tiles], objects: m[:objects], title: title, mode: mode, type: type, folder: folder)
  }
end

# <---------------------------------------------------------------------------->
#                              CONVERTING MAPS
# <---------------------------------------------------------------------------->

def convert_file(input: "attract", output: nil, input_type: "attract", output_type: "level")
  if output.nil? then output = input + "_" + output_type end
  outputRoot = output
  i = 1
  while File.exists?(output)
    output = outputRoot + i.to_s
    i += 1
  end
  map = parse_file(filename: input, type: input_type)
  generate_file(tiles: map[:tiles], objects: map[:objects], title: map[:title], type: output_type)
end

# <---------------------------------------------------------------------------->
#                           MANUAL DEMO BUILDING
# <---------------------------------------------------------------------------->

def build(tiles: [], objects: [], mode: "solo", type: "attract", title: "Generated from file")
  # Some code to generate demo
  #generate_file(tiles: tiles, objects: objects,)
end

# <---------------------------------------------------------------------------->
#                             GRAPHIC FUNCTIONS
# <---------------------------------------------------------------------------->

def coord(n) # transform N++ coordinates into pixel coordinates
  DIM * n.to_f / 4
end

def check_dimensions(image, x, y) # ensure image is within limits
  x >= 0 && y >= 0 && x <= WIDTH - image.width && y <= HEIGHT - image.height
end

def num(n)
  bl = 255
  wh = 0x008000ff
  numbers = NUMBERS.to_i(16).to_s(2).chars.map(&:to_i).map{ |b| b == 1 ? bl : wh }.each_slice(15).to_a
  digits = n.to_s.chars.map{ |d| ChunkyPNG::Image.new(NUM_WIDTH, NUM_HEIGHT, numbers[d.to_i]) }
  image = ChunkyPNG::Image.new(digits.size * (NUM_WIDTH + 1) - 1 + 2, NUM_HEIGHT + 2, 0x008000ff)
  digits.each_with_index{ |d, i| image.compose!(d, i * (NUM_WIDTH + 1) + 1, 1) }
  image
end

def generate_art(input: "metanet.png", sensitivity: 0.5, title: "autogenerated map", object: 'mine', mode: "solo", type: "level")
  hor = 4 * COLUMNS + 1
  ver = 4 * ROWS + 1
  tiles = [[0] * COLUMNS] * ROWS
  objects = []
  obj = OBJECTS.select{ |k, v| v[:name] =~ /#{object}/i }.to_a[0][0]
	image = ChunkyPNG::Image.from_file(input).resample_nearest_neighbor(hor, ver)
	output = ChunkyPNG::Image.new(hor, ver, WHITE)
	ver.times do |y|
	  hor.times do |x|
	    score = euclidean_distance_rgba(image[x,y], WHITE) / MAX_EUCLIDEAN_DISTANCE_RGBA
	    gray = (MAX * (1 - score)).round
	    if gray < 255 * sensitivity
	      output[x,y] = grayscale(gray)
	      objects << [obj, 4 + x, 4 + y, 0, 0]
	    end
	  end
	end
	output.save("metanet_new.png")
  generate_file(tiles: tiles, objects: objects, title: title, mode: mode, type: "level")
end

# This was used to create the initial masks
def create_masks(object_id, palette_id, tolerance = 0.1)
  image = ChunkyPNG::Image.from_file("images/objects/%s.png" % [object_id.to_s(16).upcase.rjust(2, "0")])
  index_a = OBJECTS[object_id][:pal]
  index_b = OBJECTS.map{ |k, v| v[:pal] }.select{ |i| i > index_a }.sort[0] || PALETTE.width
  masks = (index_a .. index_b - 1).map{ |i| mask(image, PALETTE[i, palette_id], BLACK, tolerance) }
  masks.each_with_index{ |m, i| m.save("images/object_layers/" + object_id.to_s(16).upcase.rjust(2, "0") + "-" + i.to_s + ".png") }
  return true
end

# The following two methods are used for theme generation
def mask(image, before, after, bg = WHITE, tolerance = 0.5)
  new_image = ChunkyPNG::Image.new(image.width, image.height, TRANSPARENT)
  image.width.times{ |x|
    image.height.times{ |y|
      score = euclidean_distance_rgba(image[x,y], before).to_f / MAX_EUCLIDEAN_DISTANCE_RGBA
      if score < tolerance then new_image[x,y] = ChunkyPNG::Color.compose(after, bg) end
    }
  }
  new_image
end

def generate_object(object_id, palette_id, object = true)
  parts = Dir.entries("images/#{object ? "object" : "tile"}_layers").select{ |file| file[0..2] == object_id.to_s(16).upcase.rjust(2, "0") + "-" }.sort
  masks = parts.map{ |part| [part[-5], ChunkyPNG::Image.from_file("images/#{object ? "object" : "tile"}_layers/" + part)] }
  images = masks.map{ |mask| mask(mask[1], BLACK, PALETTE[(object ? OBJECTS[object_id][:pal] : 0) + mask[0].to_i, palette_id]) }
  dims = [ [DIM, *images.map{ |i| i.width }].max, [DIM, *images.map{ |i| i.height }].max ]
  output = ChunkyPNG::Image.new(*dims, TRANSPARENT)
  images.each{ |image| output.compose!(image, 0, 0) }
  output
end

# TODO: For diagonals, I can't rotate 45º, so get new pictures or new library
def generate_image(level: {}, tiles: [], objects: [], data: "", input: "", output: "image", type: "level", theme: "vasquez", index: false)
  if !THEMES.include?(theme)
    print("Invalid theme! ")
    return
  end

  # INITIALIZE IMAGES
  tile = [0, 1, 2, 6, 10, 14, 18, 22, 26, 30].map{ |o| [o, generate_object(o, THEMES.index(theme), false)] }.to_h
  object = OBJECTS.keys.map{ |o| [o, generate_object(o, THEMES.index(theme))] }.to_h
  border = BORDERS.to_i(16).to_s(2)[1..-1].chars.map(&:to_i).each_slice(8).to_a
  image = ChunkyPNG::Image.new(WIDTH, HEIGHT, PALETTE[2, THEMES.index(theme)])

  # PARSE MAP
  if !input.empty?
    map = parse_file(filename: input, type: type)
  elsif !data.empty?
    map = parse_map(data: data, type: type)
  elsif !tiles.empty? && !objects.empty?
    map = {tiles: tiles, objects: objects}
  elsif !level.empty? && level.key?(:tiles) && level.key?(:objects)
    map = level
  else
    print("ERROR: Introduce either an 'input' filename, or map 'data', or 'tiles' and 'objects', or a 'level' hash of both.")
    return
  end
  tiles = map[:tiles].map(&:dup)
  objects = map[:objects].sort_by{ |o| -OBJECTS[o[0]][:pref] }

  # PAINT OBJECTS
  objects.each do |o|
    new_object = object[o[0]]
    (1 .. o[3] / 2).each{ |i| new_object = new_object.rotate_clockwise }
    if check_dimensions(new_object, coord(o[1]) - new_object.width / 2, coord(o[2]) - new_object.height / 2)
      image.compose!(new_object, coord(o[1]) - new_object.width / 2, coord(o[2]) - new_object.height / 2)
    end
  end

  # PAINT TILES
  tiles.each{ |row| row.unshift(1).push(1) }
  tiles.unshift([1] * (COLUMNS + 2)).push([1] * (COLUMNS + 2))
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
      image.compose!(new_tile, DIM * column, DIM * row)
    end
  end

  # PAINT TILE BORDERS
  edge = ChunkyPNG::Image.from_file('images/b.png')
  edge = mask(edge, BLACK, PALETTE[1, THEMES.index(theme)])
  (0 .. ROWS).each do |row| # horizontal
    (0 .. 2 * (COLUMNS + 2) - 1).each do |col|
      tile_a = tiles[row][col / 2]
      tile_b = tiles[row + 1][col / 2]
      bool = col % 2 == 0 ? (border[tile_a][3] + border[tile_b][6]) % 2 : (border[tile_a][2] + border[tile_b][7]) % 2
      if bool == 1 then image.compose!(edge.rotate_clockwise, DIM * (0.5 * col), DIM * (row + 1)) end
    end
  end
  (0 .. 2 * (ROWS + 2) - 1).each do |row| # vertical
    (0 .. COLUMNS).each do |col|
      tile_a = tiles[row / 2][col]
      tile_b = tiles[row / 2][col + 1]
      bool = row % 2 == 0 ? (border[tile_a][0] + border[tile_b][5]) % 2 : (border[tile_a][1] + border[tile_b][4]) % 2
      if bool == 1 then image.compose!(edge, DIM * (col + 1), DIM * (0.5 * row)) end
    end
  end

  # PAINT OBJECT INDICES
  if index
    counts = OBJECTS.map{ |k, v| [k, 0] }.to_h
    objects.each{ |o|
      count = num(counts[o[0]])
      image.compose!(count, coord(o[1]) - count.width / 2, coord(o[2]) + DIM / 2)
      counts[o[0]] += 1
    }
  end

  image.crop!(8, 10, 1920, 1080)
  image.save(output + ".png")
end
