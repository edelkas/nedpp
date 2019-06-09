require 'chunky_png'
include ChunkyPNG::Color

WIDTH = 44
HEIGHT = 44

def mask(image, original, new, tolerance)
  image.width.times{ |x|
    image.height.times{ |y|
      score = euclidean_distance_rgba(image[x,y], original).to_f / MAX_EUCLIDEAN_DISTANCE_RGBA
      if score < tolerance then image[x,y] = new end
    }
  }
  return image
end

palette = ChunkyPNG::Image.from_file('images/object_layers/entityBat.png')
n = palette.width / 64
colors = 32.step(32 + 64 * (n - 1), 64).to_a.map{ |c|
  palette[c, 32]
}
parts = (0..n - 1).map{ |p|
  ChunkyPNG::Image.from_file("images/object_layers/19-#{p}.png")
}.each_with_index{ |p, i|
  mask(p, BLACK, colors[i], 0.5)
}
output = ChunkyPNG::Image.new(WIDTH, HEIGHT, TRANSPARENT)
parts.each{ |p| output.compose!(p, 0, 0) }
output.save("test.png")

