(function() {
  var auth;

  auth = require("./middlewares/auth.js");

  module.exports = function(app) {
    var timer;
    timer = new Date().getTime();
    app.server.get("/(page/:page)?", app.controllers.mods.index);
    app.server.get("/mod/:id", app.controllers.mods.view);
    app.server.get("/mod/:id/edit/(:section)?", auth.requiresLogin, app.controllers.mods.edit);
    app.server.post("/mod/:id/edit/files", auth.requiresLogin, app.controllers.files.upload);
    app.server.get("/mod/:id/download", app.controllers.files.download);
    app.server.get("/file/:uid/delete", auth.requiresLogin, app.controllers.files.remove);
    app.server.get("/star/:slug", auth.requiresLogin, app.controllers.mods.star);
    app.server.post("/mod/:id/edit/(:section)?/post", auth.requiresLogin, app.controllers.mods.doEdit);
    app.server.get("/upload", auth.requiresLogin, app.controllers.mods.upload);
    app.server.get("/login", app.controllers.users.login);
    app.server.post("/login", function(req, res, next) {
      app.passport.authenticate("local", function(err, user, info) {
        if (err) {
          return next(err);
        }
        if (!user) {
          if (req.accepts("html")) {
            req.flash("error", "Invalid username or password");
            return res.redirect("/login" + (req.body.target ? "?target=" + req.body.target : ""));
          } else {
            if (req.accepts("json")) {
              return res.send({
                error: "invalid_credentials"
              });
            }
          }
        }
        req.logIn(user, function(err) {
          if (err) {
            return next(err);
          }
          if (req.accepts("html")) {
            return res.redirect(req.body.target || "/");
          } else {
            if (req.accepts("json")) {
              return res.send({});
            }
          }
        });
      })(req, res, next);
    });
    app.server.get("/cart/:id", app.controllers.mods.cart);
    app.server.get("/signup", app.controllers.users.signup);
    app.server.get("/user/:name", app.controllers.users.show);
    app.server.post("/signup", app.controllers.users.create);
    app.server.post("/upload", auth.requiresLogin, app.controllers.mods.doUpload);
    app.server.get("/logout", function(req, res) {
      req.logout();
      res.redirect("/");
    });
    app.server.post("/api/ajax/parse.md", app.controllers.api.parseMd);
    app.server.get("/api/ajax/login", app.controllers.api.ajaxLogin);
    app.server.get("/api/ajax/glyphicons", app.controllers.api.glyphicons);
    app.server.get("/api/cart/:cart/push/:id", app.controllers.api.addToCart);
    app.server.get("/api/cart/create", app.controllers.api.createCart);
    app.server.get("/api/cart/:cart", app.controllers.api.lsCart);
    app.server.get("/help/(:section)?.md", app.controllers.help.raw);
    app.server.get("/help/(:section)?", app.controllers.help.getHelp);
    console.log(("  Info - Loading routes took " + (new Date().getTime() - timer + "").bold + " ms").cyan);
  };

}).call(this);
