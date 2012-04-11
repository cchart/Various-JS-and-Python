exec = require('child_process').exec
fs = require 'fs.extra'
path = require 'path'
async = require 'async'
util = require 'util'
require './expansions.js'

alignExecPath = '/Applications/Hugin/Hugin.app/Contents/MacOS/align_image_stack'
hdrMergeExecPath = 'enfuse'

if process.argv.length < 3
  throw "Folder should be specified!"

fullPath = (args...) ->
  s = folder
  (s = path.join s, arg for arg in args)
  s

makeBackupFolder = (cb) ->
  backupFolder = fullPath 'backup'
  fs.stat backupFolder, (err, stats) ->
    if err
      console.log 'Making backup folder'
      fs.mkdir backupFolder, (err) -> unless_error err, -> cb()
    cb()

folder = process.argv[2]

makeBackupFolder ->
  c = 0
  fs.readdir folder, (err, files) ->
    unless_error err, ->
      for file in files
        if file.endsWith '.SH'
#          c += 1
#          unless c > 2
          fs.readFile fullPath(file), 'utf8', readShFile

alignQueue = async.queue (images, cb) ->
  allignImage images, (err) ->
    unless_error err, ->
      hdrQueue.push images, (err) -> cb()
, 2

hdrQueue = async.queue (image, cb) ->
  makeHdr image, cb
, 2

readShFile = (err, content) ->
  unless_error err, ->
    for line in content.lines
      if line.startsWith "enfuse"

        tokens = []
        backUpFuncs =
          for token in line.split /\s/ when token.startsWith "IMG"
            tokens.push token
            do (token) ->
              (cb) ->
                backUpPicture token, cb

        console.log "Starting parralel for #{tokens}"
        async.parallel backUpFuncs, (err, files) ->
          console.log "Backup done. #{files}"
          alignQueue.push [files], (err) ->
            unless_error err, ->
              console.log "Done with #{files}"

backUpPicture = (file, cb) ->
  copyFrom = fullPath file
  copyTo = fullPath 'backup', file
  console.log "doing copy of file #{file}"
  fs.copy copyFrom, copyTo, (err) ->
    mention_error err
    cb null, file

allignImage = (images, cb) ->
  execLine = "#{alignExecPath} -a #{fullPath(makePrefix(images))} -C #{images.map(fullPath).join(' ')}"
  console.log "Allign #{images} with line\n#{execLine}"
  exec execLine, (error, stdout, stderr) ->
    mention_error error
    cb()

makePrefix = (files) ->
  files.map((file) -> file.split('.')[0]).join("_") + "-"

makeHdr = (img, cb) ->
  console.log "Making HDR for #{img}"
  execLine = "#{hdrMergeExecPath} \"$@\" --output=#{img}_HDR.jpg "
  #TODO
  cb()

mention_error = (err) ->
  console.error err.message if err

unless_error = (err, func) ->
  unless err
    func.apply this
  else
    console.error err.message

