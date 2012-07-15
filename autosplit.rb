#!/usr/bin/env ruby
#
# Split is used for separating two-page scans into recto and verso images.
# It operates on directories and sub-directories full of images, appending
# "_left" and "_right" to the original filenames.
#
# Dependencies: 
#   ruby
#   rubygems
#   ImageMagick
#   RMagick gem

require 'rubygems'
require 'RMagick'



# split_image separates a jpg into two files, based on a center
# and adds to each of them a buffer of 2% of the width of
# the original
def split_image(filename, image, center)
  image_both = image #Magick::ImageList.new(input_file)
  half = center # image_both.columns / 2
  two_percent = image_both.columns / 50
#  print "lhs = image_both.crop(0, 0, #{half+two_percent}, #{image_both.rows})\n"
  lhs = image_both.crop(0, 0, half+two_percent, image_both.rows)
  ext = File.extname(filename)
  lhs.write(filename.sub(ext, "_left#{ext}"))
  start = half - two_percent
  width = image_both.columns - start
#  print "rhs = image_both.crop(#{start}, 0, #{width}, #{image_both.rows})\n"
  rhs = image_both.crop(start, 0, width, image_both.rows)
  rhs.write(filename.sub(ext, "_right#{ext}"))
  GC.start
end

# 
# draw_line is useful for debugging and testing
# it paints a red line on the part of the image passed in x
#
def draw_line(filename, image, x)
  cols = image.columns
  rows = image.rows
  redline = []
  (3*rows).times do 
    redline << Magick::Pixel.from_color('red')
  end
  image.store_pixels(x-1,0,3,rows, redline)
  ext = File.extname(filename)
  image.write(filename.sub(ext, ".autosplit#{ext}"))
end


#
# find_spine returns the X value of the darkest vertical
# stripe in the middle of the image
#
def find_spine(filename, image)
  cols = image.columns
  rows = image.rows

  # only pay attention to the middle 20% of the image
  ten_percent = (cols.to_f / 10).to_i
  start_x = (cols/2) - ten_percent
  end_x = (cols/2) + ten_percent

  # there must be a rubyier way of finding the max value
  darkest_x = 0
  # start with an impossibly high brightness
  min_brightness = 4 * 65535 * rows

  # loop through each column looking for the darkest x
  start_x.upto(end_x) do |x|
    pixels = image.get_pixels(x,0,1,rows)
    brightness = pixels.map {|p| p.red+p.green+p.blue }
    total = 0
    brightness.each { |v| total = total + v }
    if total < min_brightness
      min_brightness = total
      darkest_x = x
    end
  end

  print "spine of #{filename} is at #{darkest_x}\n"
  darkest_x
end






ARGV.each do |filename|
  deskewed_image = Magick::ImageList.new(filename).deskew
  image = deskewed_image#.edge
  center = find_spine(filename, image)
  draw_line(filename, image, center)
#  split_image(filename, image, center)
  GC.start
end
