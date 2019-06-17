# This was used to generate the palette image
# It's not a complete TGA parser, just the bare minimum required
require 'chunky_png'
include ChunkyPNG::Color

dir = '.steam/steam/steamapps/common/N++/NPP/Palettes'
palettes = Dir.entries(dir).reject{ |f| f == '.' || f == '..' }.sort_by(&:downcase)
print(palettes.to_s)
names = ["background", "ninja", "entityMine", "entityGold", "entityDoorExit",
  "entityDoorExitSwitch", "entityDoorRegular", "entityDoorLocked",
  "entityDoorTrap", "entityLaunchPad", "entityOneWayPlatform",
  "entityDroneChaingun", "entityDroneLaser", "entityDroneZap",
  "entityDroneChaser", "entityFloorGuard", "entityBounceBlock",
  "entityRocket", "entityTurret", "entityThwomp", "entityEvilNinja",
  "entityDualLaser", "entityBoostPad", "entityBat",
  "entityEyeBat", "entityShoveThwomp"].map{ |n| n + ".tga" }
output = ChunkyPNG::Image.new(91, palettes.size, WHITE)
palettes.each_with_index{ |palette, y|
  x = 0
  names.each{ |name|
    file = File.binread(dir + "/" + palette + "/" + name)
    width = file[12..13].reverse.unpack('H*')[0].to_i(16)
    colors = width / 64
    initial = 18 + 4 * 32 * width + 4 * 32
    step = 4 * 64
    (0..colors - 1).each{ |i|
      color_code = file[initial + step * i .. initial + step * i + 3]
      color = (color_code[0..2].reverse + color_code[3]).unpack('H*')[0]
      output[x,y] = ChunkyPNG::Color.from_hex(color)
      x += 1
    }
  }
}
output.save('palette.png')
