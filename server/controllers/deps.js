(function() {
  var Mod, Version, mongoose;

  mongoose = require("mongoose");

  Mod = mongoose.model("Mod");

  Version = mongoose.model("Version");

  exports.add = function(req, res) {
    console.log(req.body);
    return Mod.load({
      slug: req.params.slug,
      author: req.user._id
    }, function(err, mod) {
      if (err || !mod) {
        return status("error", 404, "not_found", "Can't found mod");
      }
      return Mod.findOne({
        slug: req.body.dep
      }, function(err, dep) {
        if (err || !dep) {
          return status("error", 400, "invalid_params", "Can't found dep!");
        }
        console.log("dep:", dep);
        return Version.findOne({
          mod: dep._id,
          name: req.body.version
        }, function(err, version) {
          version.slaves.push({
            mod: mod._id
          });
          version.save();
          return res.send("success", 200, "done", "Dependency added");
        });
      });
    });
  };

}).call(this);