var formidable = require('formidable');
var util = require('util');
var fs = require('fs');
var archiver = require('archiver');
var uuid = require('node-uuid');
var Mod = require('mongoose').model('Mod');
module.exports.upload = function(req, res) {
    var form = new formidable.IncomingForm();

    form.uploadDir = __dirname.getParent() + '/temp/';
    form.parse(req, function(err, fields, files) {
        var uid = uuid.v4();
        var newfile = __dirname.getParent() + '/uploads/' + uid;
        console.log('field:', fields);
        var versionName = fields.version;
        var path = fields.path;
        if (!path || !versionName || path === '' || versionName === '') {
            req.flash('error', 'There is something missing...');
            return res.redirect(req.url);
        }
        copyFile(files.file.path, newfile, function(err) {
            if (err) {
                console.log(err);
                req.flash('error', 'Oops, something went wrong! (reason: copy)');
                return res.redirect(req.url);
            }
            fs.unlink(files.file.path, function(err) {
                if (err) {
                    req.flash('error', 'Oops, something went wrong! (reason: deletion)');
                    return res.redirect(req.url);
                }
                var slug = req.params.id;
                Mod.load({
                    slug: slug
                }, function(err, mod) {
                    if (err || !mod) {
                        req.flash('error', 'Oops, something went wrong! (reason: database)');
                        return res.redirect(req.url);
                    }
                    mod.addFile(uid, path, versionName, function(err, doc) {
                        if (err || !mod) {
                            req.flash('error', 'Oops, something went wrong! (reason: saving)');
                            return res.redirect(req.url);
                        }
                        req.flash('success', 'Done!');
                        return res.redirect(req.url);
                    })

                })

            });

        });
    });
    /*   console.log(req.files);
    upload()//.accept('image/jpeg')
    // .gm(function(gm) {
    //    return gm.resize(false, 100);
    //   })
    .to('temp').exec(req.files['file-raw'], function(err, file) {
        if (err) req.flash('error', 'Oops! Something went wrong...');
        else req.flash('success', 'Successfully uploaded!');
        res.redirect('/');
    });*/
};

exports.download = function(req, res) {
    Mod.load({
        slug: req.params.id
    }, function(err, mod) {
        if (err || !mod) {
            res.reason = 'Mod not found';
            return res.send('Not found');
        }
        var version = req.query.v;
        if (!version) {
            return mod.listVersion(function(data) {
                res.render('mods/download.ect', {
                    versions: data
                });
            });
        }
        else {
            mod.listVersion(function(data) {
                version = version.replace('/', '#');
                var files = data[version];
                var id = uuid.v1();
                var output = fs.createWriteStream(__dirname.getParent() + '/temp/' + id);
                var archive = archiver('zip');
                archive.on('error', function(err) {
                    console.log(err);
                });

                res.set({
                    "Content-Disposition": 'attachment; filename="' + mod.name + ' v' + version + '.zip"'
                });
                archive.pipe(res);
                for (var file in files) {
                    if (files.hasOwnProperty(file)) {

                        archive.append(fs.createReadStream(__dirname.getParent() + '/uploads/' + files[file]), {
                            name: file
                        })
                        console.log('Adding file ' + files[file] + ' to ' + file);
                    }
                }
                archive.finalize(function(err, bytes) {
                    if (err) {
                        throw err;
                    }
                    console.log(bytes + ' total bytes');
                });
            });
        }
    });
}

function copyFile(source, target, cb) {
    var cbCalled = false;

    var rd = fs.createReadStream(source);
    rd.on("error", function(err) {
        done(err);
    });
    var wr = fs.createWriteStream(target);
    wr.on("error", function(err) {
        done(err);
    });
    wr.on("close", function(ex) {
        done();
    });
    rd.pipe(wr);

    function done(err) {
        if (!cbCalled) {
            cb(err);
            cbCalled = true;
        }
    }
}