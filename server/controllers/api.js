// Generated by CoffeeScript 1.6.3
(function() {
  var Cart, Mod;

  exports.ajaxLogin = function(req, res) {
    res.render("forms/login.ect");
  };

  exports.glyphicons = function(req, res) {
    var data;
    data = require("../../public/api/glyphicons.json");
    console.log(data);
    res.render("utils/glyphicons.ect", {
      list: data
    });
  };

  exports.parseMd = function(req, res) {
    return res.send(req.application.parser(req.body.markdown || ""));
  };

  Mod = require("mongoose").model("Mod");

  Cart = require("mongoose").model("Cart");

  exports.addToCart = function(req, res) {
    var cart, id;
    id = req.params.id;
    cart = req.params.cart;
    if (!id || !cart) {
      return res.send({
        status: "error",
        id: "missing_param",
        code: 400,
        message: "Something is missing..."
      });
    }
    return Cart.findById(cart, function(err, cart) {
      if (err || !cart) {
        return res.send({
          status: "error",
          id: "database_error",
          code: 500,
          message: "An error has occured with the database"
        });
      }
      cart.mods.push(id);
      cart.save();
      return res.send({
        status: "success",
        code: 201,
        message: "Successfully pushed to cart",
        data: {
          id: id,
          cart: cart
        }
      });
    });
  };

  exports.lsCart = function(req, res) {
    var id;
    id = req.params.cart;
    return Cart.findById(id).populate("mods").exec(function(err, cart) {
      return res.send(cart);
    });
  };

  exports.createCart = function(req, res) {
    var cart;
    console.log("creeating cart");
    cart = new Cart();
    cart.save();
    return res.send({
      status: "success",
      code: 201,
      message: "Successfully created cart",
      data: {
        cart: cart
      }
    });
  };

}).call(this);
