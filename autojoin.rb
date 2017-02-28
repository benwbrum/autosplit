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


def autosplit
  File.join(File.dirname(File.expand_path(__FILE__)), 'autosplit.rb')
end

def preprocess_verso(filename)
  # call autosplit
  call = "#{autosplit} --trim --fudge_factor 0 --no_detect 95 --spine_side right \"#{filename}\""
  p call
  system(call)
  # return left filename  
  ext = File.extname(filename)
  filename.sub(ext, "_left#{ext}")
end


def preprocess_recto(filename)
  # call autosplit
  call = "#{autosplit}  --trim --fudge_factor 0 --spine_side left \"#{filename}\""
  p call
  system(call)
  # return right filename
  ext = File.extname(filename)
  filename.sub(ext, "_right#{ext}")
end

def join_opening(verso, recto)
  # read files
  image = Magick::ImageList.new(verso, recto)
  # stretch when needed
  # append
  new_image = image.append(false)
  # write files
  out = verso.sub("_left", "_opening")
  p out
  new_image.write(out)
end

def process_directory(directory)
  left_filename = nil
  Dir.glob(File.join(directory, "*.*")).sort.each_with_index do |filename, i|
    if i % 2 == 0
      left_filename = preprocess_verso(filename)
    else
      right_filename = preprocess_recto(filename)
      
      join_opening(left_filename, right_filename)
    end
    GC.start
  end
end



options = {}

optparse = OptionParser.new do|opts|
  opts.banner = "Usage: autojoin.rb [options] directory1 [directory2 directory3...]"


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

ARGV.each do |dirname|
#  p options
  process_directory(dirname)
end
