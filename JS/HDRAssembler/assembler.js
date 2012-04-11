var alignExecPath, alignQueue, allignImage, async, backUpPicture, exec, folder, fs, fullPath, hdrMergeExecPath, hdrQueue, makeBackupFolder, makeHdr, makePrefix, mention_error, path, readShFile, unless_error, util,
  __slice = Array.prototype.slice;

exec = require('child_process').exec;

fs = require('fs.extra');

path = require('path');

async = require('async');

util = require('util');

require('./expansions.js');

alignExecPath = '/Applications/Hugin/Hugin.app/Contents/MacOS/align_image_stack';

hdrMergeExecPath = 'enfuse';

if (process.argv.length < 3) throw "Folder should be specified!";

fullPath = function() {
  var arg, args, s, _i, _len;
  args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  s = folder;
  for (_i = 0, _len = args.length; _i < _len; _i++) {
    arg = args[_i];
    s = path.join(s, arg);
  }
  return s;
};

makeBackupFolder = function(cb) {
  var backupFolder;
  backupFolder = fullPath('backup');
  return fs.stat(backupFolder, function(err, stats) {
    if (err) {
      console.log('Making backup folder');
      fs.mkdir(backupFolder, function(err) {
        return unless_error(err, function() {
          return cb();
        });
      });
    }
    return cb();
  });
};

folder = process.argv[2];

makeBackupFolder(function() {
  var c;
  c = 0;
  return fs.readdir(folder, function(err, files) {
    return unless_error(err, function() {
      var file, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = files.length; _i < _len; _i++) {
        file = files[_i];
        if (file.endsWith('.SH')) {
          _results.push(fs.readFile(fullPath(file), 'utf8', readShFile));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    });
  });
});

alignQueue = async.queue(function(images, cb) {
  return allignImage(images, function(err) {
    return unless_error(err, function() {
      return hdrQueue.push(images, function(err) {
        return cb();
      });
    });
  });
}, 2);

hdrQueue = async.queue(function(image, cb) {
  return makeHdr(image, cb);
}, 2);

readShFile = function(err, content) {
  return unless_error(err, function() {
    var backUpFuncs, line, token, tokens, _i, _len, _ref, _results;
    _ref = content.lines;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      line = _ref[_i];
      if (line.startsWith("enfuse")) {
        tokens = [];
        backUpFuncs = (function() {
          var _j, _len2, _ref2, _results2;
          _ref2 = line.split(/\s/);
          _results2 = [];
          for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
            token = _ref2[_j];
            if (!(token.startsWith("IMG"))) continue;
            tokens.push(token);
            _results2.push((function(token) {
              return function(cb) {
                return backUpPicture(token, cb);
              };
            })(token));
          }
          return _results2;
        })();
        console.log("Starting parralel for " + tokens);
        _results.push(async.parallel(backUpFuncs, function(err, files) {
          console.log("Backup done. " + files);
          return alignQueue.push([files], function(err) {
            return unless_error(err, function() {
              return console.log("Done with " + files);
            });
          });
        }));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  });
};

backUpPicture = function(file, cb) {
  var copyFrom, copyTo;
  copyFrom = fullPath(file);
  copyTo = fullPath('backup', file);
  console.log("doing copy of file " + file);
  return fs.copy(copyFrom, copyTo, function(err) {
    mention_error(err);
    return cb(null, file);
  });
};

allignImage = function(images, cb) {
  var execLine;
  execLine = "" + alignExecPath + " -a " + (fullPath(makePrefix(images))) + " -C " + (images.map(fullPath).join(' '));
  console.log("Allign " + images + " with line\n" + execLine);
  return exec(execLine, function(error, stdout, stderr) {
    mention_error(error);
    return cb();
  });
};

makePrefix = function(files) {
  return files.map(function(file) {
    return file.split('.')[0];
  }).join("_") + "-";
};

makeHdr = function(img, cb) {
  var execLine;
  console.log("Making HDR for " + img);
  execLine = "" + hdrMergeExecPath + " \"$@\" --output=" + img + "_HDR.jpg ";
  return cb();
};

mention_error = function(err) {
  if (err) return console.error(err.message);
};

unless_error = function(err, func) {
  if (!err) {
    return func.apply(this);
  } else {
    return console.error(err.message);
  }
};
