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
require 'optparse'
require 'pry'




# split_image separates a jpg into two files, based on a center
# and adds to each of them a buffer of 2% of the width of
# the original
def split_image(filename, image, center, options)
  image_both = image #Magick::ImageList.new(input_file)
  half = center # image_both.columns / 2
  
  # allow the percentage of slop to be variable rather than hard-wired to 2%
  two_percent = image_both.columns * ( options[:fudge_factor] / 100 )
#  print "lhs = image_both.crop(0, 0, #{half+two_percent}, #{image_both.rows})\n"
  lhs = image_both.crop(0, 0, half+two_percent, image_both.rows)
  ext = File.extname(filename)

  if options[:vertical]
    lhs.rotate(270).write(filename.sub(ext, "_below#{ext}"))  
  else
    if :spine_side == "right" || :spine_side == "center"
      lhs.write(filename.sub(ext, "_left#{ext}"))  
    end
  end


  start = half - two_percent
  width = image_both.columns - start
#  print "rhs = image_both.crop(#{start}, 0, #{width}, #{image_both.rows})\n"
  rhs = image_both.crop(start, 0, width, image_both.rows)

  if options[:vertical]
    rhs.rotate(270).write(filename.sub(ext, "_above#{ext}"))  
  else
    if :spine_side == "left" || :spine_side == "center"
      lhs.write(filename.sub(ext, "_right#{ext}"))  
    end
  end

  GC.start
end

# 
# draw_line is useful for debugging and testing
# it paints a red line on the part of the image passed in x
#
def draw_line(filename, image, x, options)
  cols = image.columns
  rows = image.rows
  redline = []
  (3*rows).times do 
    redline << Magick::Pixel.from_color('red')
  end
  image.store_pixels(x-1,0,3,rows, redline)
  ext = File.extname(filename)
  
  if options[:vertical]
    image.rotate!(270)
  end

  image.write(filename.sub(ext, "_autosplit#{ext}"))
end


#
# find_spine returns the X value of the darkest vertical
# stripe in the middle of the image
#
def find_spine(filename, image, spine_side)
  cols = image.columns
  rows = image.rows

  if spine_side == "center"
    # only pay attention to the middle 20% of the image
    ten_percent = (cols.to_f / 10).to_i
    start_x = (cols/2) - ten_percent
    end_x = (cols/2) + ten_percent
  elsif spine_side == "right"
  # pay attention to the right side of the image
    twenty_percent = (cols.to_f / 5).to_i
    start_x = cols - twenty_percent
    end_x = cols - 1
  elsif spine_side == "left"
    twenty_percent = (cols.to_f / 5).to_i
    start_x = 0
    end_x = 0 + twenty_percent
  end

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


options = {}

optparse = OptionParser.new do|opts|
  options[:no_detect] = false
  opts.on( '-n', '--no_detect', "Do not attempt to detect the spine, but split images down the middle" ) do
    options[:no_detect] = true
  end  
  
  options[:line_only] = false
  opts.on( '-l', '--line_only', "Draw a line on autodetected spine and write new image to .autosplit files" ) do
    options[:line_only] = true
  end  

  options[:vertical] = false
  opts.on( '-v', '--vertical', "Split images vertically (for notebook bindings)" ) do
    options[:vertical] = true
  end  

  options[:fudge_factor] = 2.0
  
  opts.on( '-f', '--fudge_factor NUM', Float, "Percentage of 'slop' to add over autodetected spine when cropping. (default 2)" ) do|f|
    options[:fudge_factor] = f
  end

  options[:spine_side] = "center"
  opts.on( '-s', '--spine_side left', String, "Look for the spine in the left, right, or center of the image. (default center)" ) do|side|
    options[:spine_side] = side
  end

  # This displays the help screen, all programs are
  # assumed to have this option.
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

# Parse the command-line. Remember there are two forms
# of the parse method. The 'parse' method simply parses
# ARGV, while the 'parse!' method parses ARGV and removes
# any options found there, as well as any parameters for
# the options. What's left is the list of files to resize.
optparse.parse!


ARGV.each do |filename|
  p options
  deskewed_image = Magick::ImageList.new(filename).deskew
  image = deskewed_image#.edge
  if options[:vertical]
    image.rotate!(90)
  end
  
  if options[:no_detect]
    center = image.columns / 2 #just split them in half
  else
    center = find_spine(filename, image, options[:spine_side])
  end

  if options[:line_only]
    draw_line(filename, image, center, options)
  else
    split_image(filename, image, center, options)
  end
  GC.start
end
