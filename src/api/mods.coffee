perms = require "./permissions"
validator = require "validator"
canThis = perms.canThis
mongoose = require "mongoose"
errors = error = require "../error"


###
Lists the mods and pass them to the then with a `totalCount` property that counts the mods
@param userid the current logged user
@param options the options
@permission mod:browse
###
exports.list = ((userid, options, callback) ->
  canThis(userid, "mod", "browse").then (can)->
    if can is false
      callback(error.throwError("Forbidden", "UNAUTHORIZED"))
    # Validate options
    if options.perPage > 50
      callback(error.throwError("Too much mods per page", "INVALID_PARAMS"))
    Mod = mongoose.model "Mod"
    Mod.list options, (err, mods) ->
      return callback error.throwError(err, "DATABASE_ERROR") if err
      Mod.count().exec (err, count) ->
        mods.totalCount = count
        errors.handleResult err, mods, callback

    return
).toPromise @


###
Return a mod
@param userid the current logged user id or ""
@param slug the slug of the mod
@param cart the current cart id or null
@param user the current user for edition ({})
@permission mod:browse
###
exports.view = ((userid, slug, cart, user, parse ,callback) ->
  canThis(userid, "mod", "browse").then (can)->
    if can is false
      callback(error.throwError("Forbidden", "UNAUTHORIZED"))
    # Validate options

    Mod = mongoose.model "Mod"
    Mod.load
      slug: slug
      $cart_id: cart
      $user: user
      $populate: true
    , (err, mod) ->
      if not mod
        return callback(error.throwError("Not found", "NOT_FOUND"))
      if err
        return callback(error.throwError(err, "INVALID_PARAMS"))
      mod = mod.toObject()
      if parse is true then mod.htmlbody = require("../parser")(mod.body)
      Version = mongoose.model "Version"
      Version.find {mod: mod._id}, (err, versions) ->
        if err or not mod
          return handleResult(err, mod, callback)
        output = {}
        for version in versions
          output[version.name] = output[version.name] or {}
          for file in version.files
            output[version.name][file.path] = file.uid
        mod.versions = output
        return callback mod

    return

    return
).toPromise @


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

exports.star = ((userid, slug, callback) ->
  canThis(userid, "mod", "star").then (can)->
    try
      if can is false
        callback(error.throwError("Forbidden", "UNAUTHORIZED"))
      # Validate options
      Mod = mongoose.model "Mod"
      q = Mod.findOne
        slug: slug
        "stargazers.id": userid
      ,
        "stargazers.$": 1
      q.exec (err, mod) ->
        return callback err  if err
        Mod.findOne
          slug: slug
        , (err, doc) ->
          return callback err  if err
          console.log "hu3.5"
          if !mod
            try
              doc.stargazers.push
                id: userid
                date: Date.now()
              doc.vote_count = (doc.vote_count or 0) + 1
            catch err
              console.log err
          else
            doc.vote_count--
            doc.stargazers.id(mod.stargazers[0]._id).remove()
          doc.save (err, mod) ->
            errors.handleResult err, mod, callback
    catch err
      console.log err

).toPromise @

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
    Mod.load
      slug: slug
    , (err, mod) ->
      if can is false and mod.author.equals(userid) isnt true
        callback(error.throwError("Forbidden", "UNAUTHORIZED"))
      if err or not mod
        callback err
      mod.addFile uid, path, versionName, (err, doc) ->
        errors.handleResult err, doc, callback

).toPromise @




