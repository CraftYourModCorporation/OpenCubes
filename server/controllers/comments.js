(function() {
  var Mod;

  Mod = require("mongoose").model("Mod");

  exports.addComment = function(req, res) {
    return Mod.findOne({
      slug: req.params.slug
    }, function(err, mod) {
      console.log(req.body);
      if (err || !mod) {
        return res.send(status("error", 500, "database_error", "Error with database. Please try again."));
      }
      mod.comments.push({
        title: req.body.name,
        body: req.body.body,
        date: Date.now(),
        author: req.user._id
      });
      mod.save();
      return res.send(status("success", 200, "Posted!"));
    });
  };

  exports.editComment = function(req, res) {};

  exports.removeComment = function(req, res) {};

}).call(this);
