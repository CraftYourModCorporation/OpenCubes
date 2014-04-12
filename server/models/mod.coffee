mongoose = require("mongoose")
Schema = mongoose.Schema
Cart = mongoose.model("Cart")
slug = require("mongoose-slug")
timestamps = require("mongoose-times")
ModSchema = mongoose.Schema(
  name: String
  version: String
  author:
    type: Schema.Types.ObjectId
    ref: "User"

  summary: String
  body: String
  logo: String
  dl_id: String
  creation_date: Date
  lmodified_date: Date
  category: String
  vote_count: Number
  stargazers: [
    id: Schema.Types.ObjectId
    date: Date
  ]
  comments: [
    author:
      type: Schema.Types.ObjectId
      ref: "User"
    title: String
    body: String
    date: Date
  ]
  versions: [name: String]
)
ModSchema.path("name").required true, "Mod title cannot be blank"
ModSchema.path("body").required true, "Mod body cannot be blank"
ModSchema.plugin slug("name")
ModSchema.plugin timestamps
ModSchema.methods =
  fillCart: (cart)->
    @carted = true for mod in cart.mods when mod.toString() is @_id.toString()
    return

  fillStargazer: (luser) ->
    @starred = true for user in @stargazers when ""+user.id.toString() is ""+luser._id
    return

  addVersion: (data, cb) ->
    v = @versions.push(data)
    self = this
    @save (err, doc) ->
      return cb(err)  if err
      self.getVersion data, cb
      return

    return

  getVersion: (data, cb) ->
    v = @versions.findIn(data)
    console.log v
    cb `undefined`, v

  
  ###
  Create the version by name if it does not exists
  ###
  getOrCreateVersion: (name, cb) ->
    self = this
    @getVersion
      name: name
    , (err, doc) ->
      if not doc or err or doc is -1
        return self.addVersion(
          name: name
        , cb)
      cb err, doc
      return

    return

  addFile: (uid, path, version, cb) ->
    mongoose.model("File").createFile uid, path, this, version, cb
    return

  deleteFile: (uid, cb) ->
    mongoose.model("File").remove
      uid: uid
    , cb
    return

  
  ###
  Output:
  
  {
  "version1": {
  "path": "uid"
  }...
  }
  ###
  listVersion: (cb) ->
    File = mongoose.model("File")
    list = (versions, i, data) ->
      return cb(data)  if i is versions.length
      File.find(version: versions[i]._id).sort("path").exec (err, doc) ->
        return console.log(err)  if err
        verName = versions[i].name
        files = {}
        doc.forEach (file) ->
          files[file.path] = file.uid
          return

        data[verName] = files
        i++
        list versions, i, data
        return

      return

    list @versions, 0, {}
    return

ModSchema.statics =
  
  ###
  Find article by id
  
  @param {ObjectId} id
  @param {Function} cb
  @api private
  ###
  load: (data, cb) ->
    cartId = data.$cart_id
    user = data.$user
    data.$cart_id = undefined
    data.$user = undefined
    query = @findOne(data)
    query.populate "comments.author"
    query.exec (err, mod) ->
      if cartId
        return Cart.findById(cartId, (err, cart)->
          if !err and cart
            mod.fillCart cart
          if user
            mod.fillStargazer user
          cb(err, mod)
        )
      cb err, mod
    return

  
  ###
  List articles
  
  @param {Object} options
  @param {Function} cb
  @api private
  
  ###
  list: (options, cb) ->
    criteria = options.criteria or {}
    @find(criteria).sort(options.sort)
      .limit(options.perPage).populate("author", "username")
      .skip(options.perPage * options.page)
      .exec (err, mods) ->
        if err or !mods
          return cb err, mods
        if options.cart
          Cart.findById(options.cart, (err, cart)->
            if !err and cart
              mod.fillCart cart for mod in mods
              cb(err, mods)
          )
        else
          cb(err, mods)
              
    return

mongoose.model "Mod", ModSchema
