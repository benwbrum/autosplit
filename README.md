autosplit
=========

Splits a single image containing two scanned pages into
two images with one image per page.

Requires the RMagick gem.

```
Usage: autosplit [options] filename
      -n, --no_detect                  Do not attempt to detect the spine, but split images down the middle
      -l, --line_only                  Draw a line on autodetected spine and write new image to .autosplit files
      -v, --vertical                   Split images vertically (for notebook bindings)
      -f, --fudge_factor NUM           Percentage of 'slop' to add over autodetected spine when cropping. (default 2)
      -h, --help   
```

Released under the MIT license
