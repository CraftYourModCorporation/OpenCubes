perms = require "./permissions"
validator = require "validator"
canThis = perms.canThis
mongoose = require "mongoose"
errors = error = require "../error"
_  = require("lodash")
parse = require "../parser"
Q = require "q"
qfs = require("q-io/fs")
async = require "async"
Mod = mongoose.model "Mod"
Star = mongoose.model "Star"
User = mongoose.model "User"
mongooseQ = require("mongoose-q")()

exports.check = (slug) ->
  q = Mod.findOne slug: slug
  q.select "name author created logo slug"
  q.exec()
###
Return the latest mods
@params limit the max amount of mods
###
exports.getLatestMods = (limit=6) ->
  deferred = Q.defer()
  Mod.find()
  .select("name vote_count author summary created logo slug")
  .sort("-created")
  .limit(limit)
  .exec (err, mods) ->
    if err then return deferred.reject err
    deferred.resolve mods
  deferred.promise

###
Returns the most popular mod ever
@params limit the aximum amiunt of mods
###
exports.getPopularMods = (limit=6) ->
  deferred = Q.defer()
  Mod.find()
  .select("name vote_count author created logo slug")
  .sort("-vote_count")
  .limit(limit)
  .exec (err, mods) ->
    if err then return deferred.reject err
    deferred.resolve mods
  deferred.promise

###
Get the trending mods for a period defined by a duration and a date,
that is to say the mods that got the most stars in this period
@params limit the max amount of mods
@api.error v2
###
exports.getTrendingMods = (limit=6) ->
  deferred = Q.defer()
  Mod.find()
  .populate("author")
  .select("name author cached summary slug created lastUpdated")
  .sort("-cached.stats.downloads")
  .limit(limit)
  .lean()
  .exec (err, mods) ->
    return deferred.reject new DatabaseError() if err
    deferred.resolve mods
  deferred.promise

###
Lists the mods
@param criterias the criterias
@param options the options
@permission mod:browse
###
exports.itemize = ($criterias, options) ->
  regexpCriterias = /name|description|summary|category|slug|author/
  criterias = {}
  deferred = Q.defer()
  result = {}

  for own key, value of $criterias
    if key.match regexpCriterias
      if value.match /\*((\w|\d|_|-\s)+)/g
        criterias[key] = new RegExp(/\*((\w|_|\d|-\s)+)/g.exec(value)[1],"gi")
      else
        criterias[key] = value.replace((/[^a-zA-Z\s\d-_]/g), "")

  # Validate options
  if options.limit > 100
    deferred.reject(error.throwError("Too much mods per page", "INVALID_PARAMS"))

  # start finding
  Mod = mongoose.model "Mod"
  Mod.find(criterias)
  # limit
  .limit(options.limit or 25)
  # skip items
  .skip(options.skip or 0)
  # sort order
  .sort(options.sort or "-created")
  # select and lean
  .select("-body -logo -stargazers -comments").lean()
  .exec().then((mods) ->
    result.mods = mods
    # count the mods
    return Mod.count(criterias).exec()
  , deferred.reject).then((count) ->
    result.totalCount = count
    result.status = "success"
    criterias[k] = criterias[k].toString() for k of criterias
    result.query =
      criterias: criterias
      options: options
    for mod of result.mods
      result.mods[mod].links =
        http: "/api/v1/mods/#{result.mods[mod].slug}"
        html: "/mods/#{result.mods[mod].slug}"
        logo: "/assets/#{result.mods[mod].slug}.png"
    deferred.resolve result
  , deferred.reject)

  return deferred.promise


###
Lists the mods and pass them to the then with a `totalCount` property that counts the mods
@param userid the current logged user
@param options the options
@permission mod:browse
###
exports.list = (userid, options, callback) ->
  deferred = Q.defer()
  # Validate options
  if options.perPage > 50
    deferred.reject(error.throwError("Too much mods per page", "INVALID_PARAMS"))
  Mod = mongoose.model "Mod"
  Mod.list options, (err, mods) ->
    return deferred.reject error.throwError(err, "DATABASE_ERROR") if err
    Mod.count().exec (err, count) ->
      mods.totalCount = count
      if err
        deferred.reject err
      deferred.resolve mods

  deferred.promise

###
Return a mod description, title and quick informations
@param userid the current logged user id or ""
@param slug the slug of the mod
@param options additional options :
{
  cart: cart, // cart._id or null
  loggedUser: user,  // user for edtion
  doParse: true // should we parse the mod
}
@permission mod:browse
###
exports.lookup = (userid, slug, options) ->
  deferred = Q.defer()
  if not options
    callback = options
    options = {}
  options = _.assign options,{cart: undefined, loggedUser: undefined, doParse: true}
  cartId = options.cart
  canThis(userid, "mod", "browse").then (can)->
    try
      if can is false
        cb(error.throwError("Forbidden", "UNAUTHORIZED"))
      # Validate options
      Mod = mongoose.model "Mod"
      q = {}
      if /[0-9a-f]{24}/.test slug
        q._id = slug
      else
        q.slug = slug
      query = Mod.findOne q
      query.select("name slug body description summary comments logo created
       updatedAt author category cached.rating cached.rating_count
       cached.versions cached.versions_count images")
      query.populate("author", "name")
      query.populate("comments.author", "username")
      query.lean()
      query.exec((err, mod) ->
        if not mod then return deferred.resolve mod
        if cartId and mod
          return Cart.findById(cartId, (err, cart)->
            if !err and cart
              mod.fillCart cart

            if err
              return deferred.reject err
            deferred.resolve mod
          )
        mod.htmlbody = parse mod.body
        if err
          return deferred.reject err
        deferred.resolve mod
      )
    catch err
      console.log err.stack.red
      return deferred.reject err


###
Return a mod description, title and quick informations
@param userid the current logged user id or ""
@param slug the slug of the mod
@param options additional options :
{
  cart: cart, // cart._id or null
  loggedUser: user,  // user for edtion
  doParse: true // should we parse the mod
}
@permission mod:browse
###
exports.getLogo = ((userid, slug, options, callback) ->
  Mod = mongoose.model "Mod"
  query = Mod.findOne({slug: slug})
  query.select("logo")
  query.lean()
  query.exec().then((mod) ->
    callback mod
  , (err)->
    callback err
  )
).toPromise @

uuid = require("node-uuid")
fs = require("fs")

exports.setLogo = (req, res) ->
  file = req.files.file
  if(!file)
    res.send 401, "missing file"
  uid = uuid.v4() + ".png"
  newfile = __dirname.getParent() + "/uploads/" + uid
  fs.rename file.path, newfile, (err) ->
    if err
      console.log err
      return res.send 500, "something went wrong while moving"
    app.api.mods.edit(req.getUserId(), req.params.id, "logo", uid).then((status) ->
      res.send 200, "Saved!"
    ).fail (err) ->
      errors.handleHttp err, req, res, "text"

###
Return a mod fully loaded with deps and versions
@param userid the current logged user id or ""
@param slug the slug of the mod
@permission mod:edit
###

exports.load = ((userid, slug, callback) ->
  canThis(userid, "mod", "browse").then (can)->
    # Validate options

    Mod = mongoose.model "Mod"
    Mod.load
      slug: slug
    , (err, mod) ->
      if can is false and mod.author isnt userid
        callback(error.throwError("Forbidden", "UNAUTHORIZED"))
      if err or not mod
        return handleResult(err, mod, callback)
      mod.fillDeps (err, deps)->
        if err or not deps
          handleResult
        mod.listVersion (v) ->
          container =
            mod: mod
            deps: deps
            versions: v
          callback container
).toPromise @

###
Edit a mod
@param userid the current logged user id
@param slug the slug of the mod
@param field the field to be edited
@param value the new value
@permission mod:edit
###

exports.edit = ((userid, slug, field, value, callback) ->
  canThis(userid, "mod", "browse").then (can)->
    # Validate options

    Mod = mongoose.model "Mod"

    Mod.findOne {slug: slug}, (err, mod) ->
      if can is false and mod.author isnt userid
        callback(error.throwError("Forbidden", "UNAUTHORIZED"))
      if err or not mod
        return handleResult(err, mod, callback)
      mod[field] = value
      mod.save (err, mod) ->
        errors.handleResult err, mod, callback


).toPromise @
###
Edit a mod
@param userid the current logged user id
@param slug the slug of the mod
@param body
@permission mod:edit
###

exports.put = (userid, slug, body) ->
  deferred = Q.defer()
  screen = body.screens
  body = _.pick body, ['name', 'body', 'summary', 'category']
  canThis(userid, "mod", "browse").then (can)->
    # Validate options
    Mod = mongoose.model "Mod"

    Mod.findOne {slug: slug}, (err, mod) ->
      if can is false and mod.author isnt userid
        deferred.reject(error.throwError("Forbidden", "UNAUTHORIZED"))
      if err or not mod
        return handleResult(err, mod, deferred.reject)
      mod = _.assign mod, body
      if screen then mod.images.push screen
      mod.save (err, mod) ->
        if err
          return deferred.reject err

        deferred.resolve
          result: mod
          query:
            body: body


  return deferred.promise


###
Upload a mod
@param userid the current logged user id
@param mod the data of the new mod
@permission mod:add
###

exports.add = ((userid, mod, callback) ->
  canThis(userid, "mod", "add").then (can)->
    if can is false
      callback(error.throwError("Forbidden", "UNAUTHORIZED"))
    # Validate options

    Mod = mongoose.model "Mod"
    mod = new Mod mod
    mod.save((err, mod)->
      errors.handleResult err, mod, callback
    )

).toPromise @

###
Star a mod
@param userid the current logged user id
@param mod the data of the mod
@permission mod:star
###

exports.star = (userid, slug, date=Date.now(), dont_check=false) ->
  console.log("STARS ARE DEPRECATED. ABORTING".red)
  return
  deferred = Q.defer()
  canThis(userid, "mod", "star").then (can)->
    if can is false
      deferred.reject(error.throwError("Forbidden", "UNAUTHORIZED"))
    # Validate options
    Mod = mongoose.model "Mod"
    mod = {}
    Star = mongoose.model "Star"
    q = Mod.findOne
      slug: slug
    q.select "slug name author vote_count logo"
    q.exec().then (doc) ->
      mod = doc
      Star.findOne
        user: userid
        mod: mod._id
      .exec()
    .then (star) ->
      if star and not dont_check
        mod.vote_count--
        mod.save()
        star.remove()
        deferred.resolve mod
        return
      star = new Star
        user: userid
        mod: mod._id
        date: date
      star.save()
      mod.vote_count = (mod.vote_count or 0) + 1
      mod.save()
      deferred.resolve mod
      return
    , deferred.reject
  deferred.promise

###
Search a mod
@param userid the current logged user id
@param query the query string
@permission mod:browse
###

exports.search = ((userid, query, callback) ->
  canThis(userid, "mod", "browse").then (can)->
    if can is false
      callback(error.throwError("Forbidden", "UNAUTHORIZED"))
    # Validate options
    Mod = mongoose.model "Mod"
    regex = new RegExp(query, 'i')
    q = Mod.find({name: regex})
    q.populate("author", "username")
    q.exec (err, mods) ->
      errors.handleResult err, mods, callback

).toPromise @

###
Add a file to a mod
@param userid the current logged user id
@param slug the slug of the mod
@param uid the uid (name) of the files loacted in uploads
@param path the target path
@param versionName the version of the mod
@permission mod:edit
###

exports.addFile = ((userid, slug, uid, path, versionName, callback) ->
  canThis(userid, "mod", "edit").then (can)->
    # Validate options
    Mod = mongoose.model "Mod"
    q = Mod.findOne
      slug: slug
    q.select("name slug author")
    q.exec (err, mod) ->
      if can is false and mod.author.equals(userid) isnt true
        return callback(error.throwError("Forbidden", "UNAUTHORIZED"))
      if err or not mod
        return callback err
      mod.addFile uid, path, versionName, (err, doc) ->
        errors.handleResult err, doc, callback

).toPromise @

###
Remove a file from a mod
@param userid the current logged user id
@param slug the slug of the mod
@param versionName the version of the mod
@param uid the uid (name) of the files loacted in uploads
@permission mod:edit
###
exports.removeFile = (userid, slug, v, uid) ->
  deferred = Q.defer()
  Mod = mongooseQ.model "Mod"
  Version = mongooseQ.model "Version"
  can = false
  canThis(userid, "mod", "edit").then (can_) ->
    can = can_
    # Find the mod
    Mod.findOne(slug: slug).select("name slug author").execQ()
  .then (mod) ->

    # Perm check
    if can is false and mod.author.equals(userid) isnt true
      return callback(error.throwError("Forbidden", "UNAUTHORIZED"))

    # Mod found?
    if not mod
      return deferred.reject new Error(404)

    # Find version
    Version.findOneQ
      mod: mod._id
      name: v
  .then (version) ->

    # Remove file
    for file in version.files
      console.log file.uid, uid
      if file.uid is uid
        file.remove()
        return version.saveQ()

    # Nothing was found
    deferred.reject new Error(404)
    return
  .then ->

    # remove file
    qfs.remove "../uploads/" + uid
  .then ->
    deferred.resolve {}
  .fail deferred.reject

  deferred.promise


###
Get the file of a mod
@param userid the current logged user id
@param slug the slug of the mod
@param uid the uid (name) of the files loacted in uploads
@param path the target path
@param versionName the version of the mod
@permission mod:edit
###

exports.getFiles = ((slug, version, callback) ->
  # Validate options
  Mod = mongoose.model "Mod"
  Version = mongoose.model "Version"

  query = Mod.findOne({slug: slug})
  query.select("name slug")
  query.exec().then((mod) ->
    return Version.findOne({mod: mod._id, name: version}).exec()
  ).then((version) ->
    callback version.files
  , (err) ->
    errors.handleResult err, callback
  )
).toPromise @
###
Get the versions of the mod
@param slug the slug of the mod
@permission mod:edit
###

exports.getVersions = (slug) ->
  deferred = Q.defer()
  # Validate options
  Mod = mongoose.model "Mod"
  Version = mongoose.model "Version"

  query = Mod.findOne({slug: slug})
  query.select("name slug")
  query.exec().then((mod) ->
    return Version.find({mod: mod._id}).exec()
  ).then((versions) ->
    data = []
    i = 0
    data[i++] = version.toObject() for version in versions when version isnt undefined
    deferred.resolve data
  )
  deferred.promise

###
Get the stats of the mod
@param userid the current logged user id
@param slug the slug of the mod
@param name the stats wanted
@permission mod:edit
###

exports.getStats = (userid, slug, name, type="day") ->
  deferred = Q.defer()
  all = (type is "all")
  if all then type = "day"
  canThis(userid, "mod", "browse").then (can)->
    if can is false
      callback(error.throwError("Forbidden", "UNAUTHORIZED"))
    # Validate options
    Mod = mongoose.model "Mod"
    Star = mongoose.model "Star"
    Mod.findOne(slug: slug).select("name slug").exec()
  .then (mod) ->
    if not mod then return deferred.resolve()
    $match =
      "mod": mod._id,
  #  $match["time_bucket.#{type}"] = new TimeBucket()[type]
    Star.aggregate [
      {
        $match: $match
      },
      {
        $group:
          _id: "$time_bucket.#{type}",
          stars:
            "$sum": 1
      },
      {
        $sort:
          _id: 1
      }
    ], (err, mods) ->
      dates = []
      time = Date.now()
      i = 0
      max = switch
        when type is "day"   then 32
        when type is "month" then 24
        when type is "hour" then 24
        when type is "year"  then 3
        else 0
      if all then max = mods.length
      while i < max
        dates.push new TimeBucket(new Date(time - (if type is "year" then 12 else 1)  * (if type is "month" then 31 else 1) * 24 * 3600 * 1000 * i))[type]
        i++

      dates= dates.reverse()
      data = {}
      mods.forEach (value) ->
        data[value._id] = value.stars
      r = dates.map (el) ->
        return data[el] || 0
      deferred.resolve {data: r, labels: dates}

  deferred.promise
###
Get the version of the mod
@param userid the current logged user id
@param slug the slug of the mod
@param name the version of the mod
@permission mod:edit
###

exports.getVersion = (slug, name) ->
  deferred = Q.defer()
  # Validate options
  Mod = mongoose.model "Mod"
  Version = mongoose.model "Version"

  query = Mod.findOne({slug: slug})
  query.select("name slug")
  query.exec().then((mod) ->
    return Version.findOne({mod: mod._id, name: name}).exec()
  ).then((versions) ->
    deferred.resolve versions
  )
  deferred.promise


###
Get the version of the mod
@param userid the current logged user id
@param slug the slug of the mod
@param name the version of the mod
@permission mod:edit
###

exports.addVersion = (slug, name) ->
  deferred = Q.defer()
  # Validate options
  Mod = mongoose.model "Mod"
  Version = mongoose.model "Version"
  modid = undefined
  auth = undefined
  query = Mod.findOne({slug: slug})
  query.select("name slug author")
  query.exec().then((mod) ->
    modid = mod._id
    auth = mod.author
    return Version.findOne({mod: mod._id, name: name}).exec()
  ).then((version) ->
    if version
      return deferred.resolve version
    version = new Version()
    console.log auth
    version.author = auth
    version.name = name
    version.mod = modid
    version.save (err, v) ->
      if err then deferred.reject err
      deferred.resolve v
  )
  deferred.promise
###
Removes a version

@param user the current logged user id
@param slug the slug of the mod
@param name the version of the mod
@permission mod:edit
@return promise
###

exports.removeVersion = (user, slug, name) ->
  deferred = Q.defer()
  Mod = mongoose.model "Mod"
  Version = mongoose.model "Version"
  modid = undefined
  auth = undefined
  query = Mod.findOne slug: slug
  query.select("name slug author")
  query.exec().then (mod) ->
    modid = mod._id
    auth = mod.author
    return Version.findOne({mod: mod._id, name: name}).exec()
  .then (version) ->
    if not version then return deferred.reject new Error(404)
    if not auth.equals user then return deferred.reject new Error(403)
    version.remove ->
      deferred.resolve version
  deferred.promise

###
Removes a mod
@param user the current user
@param slug the mod's slug
@return promise
@api.error v2
###

exports.removeMod = (user, slug) ->
  deferred = Q.defer()
  Mod = mongooseQ.model "Mod"
  modid = undefined
  can = false
  canThis(user, "mod", "browse").then (can$) ->
    can = can$
    query = Mod.findOne slug: slug
    query.execQ()
  .then (mod) ->
    if not mod then return deferred.reject new NotFoundError()
    if not mod.author.equals(user) and not can
      return deferred.reject(new ForbiddenError())
    mod.removeQ()
  .then deferred.resolve
  .fail console.log
  deferred.promise
