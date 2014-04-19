// Generated by CoffeeScript 1.6.3
(function() {
  var canThis, mongoose, perms, validator;

  perms = require("./permissions");

  validator = require("validator");

  canThis = perms.canThis;

  mongoose = require("mongoose");

  /*
  Lists the mods and pass them to the then with a `totalCount` property that counts the mods
  @param userid the current logged user
  @param options the options
  @permission mod:browse
  */


  exports.list = (function(userid, options, callback) {
    return canThis(userid, "mod", "browse").then(function(can) {
      var Mod;
      if (can === false) {
        return callback(new Error("unauthorized"));
      }
      if (options.perPage > 50) {
        return callback(new Error("invalid_args"));
      }
      Mod = mongoose.model("Mod");
      Mod.list(options, function(err, mods) {
        if (err) {
          return callback(err);
        }
        return Mod.count().exec(function(err, count) {
          mods.totalCount = count;
          return callback(mods);
        });
      });
    });
  }).toPromise(this);

  /*
  Return a mod
  @param userid the current logged user id or ""
  @param slug the slug of the mod
  @param cart the current cart id or null
  @param user the current user for edition ({})
  @permission mod:browse
  */


  exports.view = (function(userid, slug, cart, user, callback) {
    return canThis(userid, "mod", "browse").then(function(can) {
      var Mod;
      if (can === false) {
        return callback(new Error("unauthorized"));
      }
      Mod = mongoose.model("Mod");
      Mod.load({
        slug: slug,
        $cart_id: cart,
        $user: user
      }, function(err, mod) {
        if (err || !mod) {
          return callback(new Error("not_found"));
        }
        mod.htmlbody = require("../parser")(mod.body);
        return callback(mod);
      });
      return;
    });
  }).toPromise(this);

  /*
  Return a mod fully loaded with deps and versions
  @param userid the current logged user id or ""
  @param slug the slug of the mod
  @permission mod:edit
  */


  exports.load = (function(userid, slug, callback) {
    return canThis(userid, "mod", "browse").then(function(can) {
      var Mod;
      Mod = mongoose.model("Mod");
      return Mod.load({
        slug: slug
      }, function(err, mod) {
        if (can === false && mod._id !== userid) {
          return callback(new Error("unauthorized"));
        }
        if (err || !mod) {
          return callback(new Error("unauthorized"));
        }
        return mod.fillDeps(function(err, deps) {
          if (err || !deps) {
            return callback(new Error("database_error"));
          }
          return mod.listVersion(function(v) {
            var container;
            container = {
              mod: mod,
              deps: deps,
              versions: v
            };
            return callback(container);
          });
        });
      });
    });
  }).toPromise(this);

  /*
  Edit a mod
  @param userid the current logged user id 
  @param slug the slug of the mod
  @param field the field to be edited
  @param value the new value
  @permission mod:edit
  */


  exports.edit = (function(userid, slug, field, value, callback) {
    return canThis(userid, "mod", "browse").then(function(can) {
      var Mod;
      if (can === false) {
        return callback(new Error("unauthorized"));
      }
      Mod = mongoose.model("Mod");
      return Mod.findOne({
        slug: slug
      }, function(err, mod) {
        if (can === false && mod._id !== userid) {
          return callback(new Error("unauthorized"));
        }
        if (err || !mod) {
          if (err) {
            console.log(err);
          }
          return callback(new Error("Please try again"));
        }
        mod[field] = value;
        mod.save();
        return callback("ok");
      });
    });
  }).toPromise(this);

}).call(this);
