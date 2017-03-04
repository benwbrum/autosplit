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
require 'rmagick'
require 'optparse'
require 'pry'
require 'pry-byebug'


# split_image separates a jpg into two files, based on a center
# and adds to each of them a buffer of 2% of the width of
# the original
def split_image(filename, image, center, options)
  image_both = image #Magick::ImageList.new(input_file)
  half = center # image_both.columns / 2
  
  # allow the percentage of slop to be variable rather than hard-wired to 2%
  two_percent = image_both.columns * ( options[:fudge_factor] / 100 )
#  print "lhs = image_both.crop(0, 0, #{half+two_percent}, #{image_both.rows})\n"
  lhs = image_both.crop(0, 0, half+two_percent, image_both.rows, true)
 
  ext = File.extname(filename)

  if options[:vertical]
    lhs.rotate(270).write(filename.sub(ext, "_below#{ext}"))  
  else
    if options[:spine_side] == "right" || options[:spine_side] == "center"
      lhs.write(filename.sub(ext, "_left#{ext}"))  
    end
  end


  start = half - two_percent
  width = image_both.columns - start
#  print "rhs = image_both.crop(#{start}, 0, #{width}, #{image_both.rows})\n"
  rhs = image_both.crop(start, 0, width, image_both.rows, true)

  if options[:vertical]
    rhs.rotate(270).write(filename.sub(ext, "_above#{ext}"))  
  else
    if options[:spine_side] == "left" || options[:spine_side] == "center"
      rhs.write(filename.sub(ext, "_right#{ext}"))  
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


def find_edge(image, x_fraction, orientation)
  x = (image.columns.to_f * x_fraction).to_i
  
  if orientation == :top
    pixels = image.get_pixels(x,0,1,(image.rows * 0.3).to_i)
    brightness = pixels.map {|p| p.red+p.green+p.blue }       
  else
    pixels = image.get_pixels(x,(image.rows * 0.7).to_i,1,(image.rows * 0.3).to_i)
    brightness = pixels.map {|p| p.red+p.green+p.blue }.reverse       
  end
  
  (brightness.size - 10).times do |i|
    slice = brightness[i .. i+10]
    slice_brightness = slice.inject(0) { |accum,el| accum+el }
#    print "Slice #{x_fraction} #{i}\t=\t#{slice_brightness}\n"
    return i if slice_brightness > 1500000 # this works for black-and-white scans
  end
  0
end


def trim(image)
  top_border = [find_edge(image, 0.4, :top), find_edge(image, 0.5, :top), find_edge(image, 0.6, :top)].min
  
  bottom_border = [find_edge(image, 0.4, :bottom), find_edge(image, 0.5, :bottom), find_edge(image, 0.6, :bottom)].min

  trimmed_height = image.rows - (top_border+bottom_border)
  image.crop(0, top_border, image.columns, trimmed_height, true)
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
  opts.banner = "Usage: autosplit.rb [options] file1 [file2 file3...]"

  options[:no_detect] = nil
  opts.on( '-n', '--no_detect NUM', Integer, "Do not attempt to detect the spine, but split images on a fixed percentage (default 50)" ) do |center|
    options[:no_detect] = center.to_i
  end  
  
  options[:trim] = false
  opts.on( '-t', '--trim', "Trim dark background from top and bottom of image" ) do
    options[:trim] = true
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

if ARGV.empty?
  puts optparse.help
  exit 
end

ARGV.each do |filename|
#  p options
  image = Magick::ImageList.new(filename)

  if options[:vertical]
    image.rotate!(90)
  end

  if options[:trim]
    image = trim(image)
  end
  
  image = image.deskew

  if options[:no_detect]
    center = image.columns * (options[:no_detect] * 0.01) #just split them by percentage
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
