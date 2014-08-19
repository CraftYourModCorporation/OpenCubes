mongoose = require("mongoose")
Q = require "q"
Schema = mongoose.Schema
  author:
    type: mongoose.Schema.Types.ObjectId
    ref: "User"

  subject:
    type: mongoose.Schema.Types.ObjectId

  object_id:
    type: mongoose.Schema.Types.ObjectId

  verb: String

  date: Date

Schema.methods =
  fill: ->
    Mod = mongoose.model "Mod"
    Version = mongoose.model "Version"
    deferred = Q.defer()
    self = @
    _then = (subject, object) ->
      obj = self.toObject()
      obj.subject = subject
      obj.object_id = object
      deferred.resolve obj
    switch @verb
      when "release"
        # The object is a version
        Q.all([Mod.findById(@subject).select("name slug").exec(),
          Version.findById(@object_id).select("name").exec()]).spread _then
    deferred.promise

Schema.statics =
  notify: (object) ->
    Subscription = mongoose.model "Subscription"
    n = new @(object)
    n.date = n.date or new Date()
    n.save (err, obj) ->
      id = obj._id
      console.log "object", object
      Subscription.update {
        'subscriptions.obj': object.subject
        'subscriptions.filter': object.verb
      }, {
        '$addToSet': {
          'notifications': {
            'nid': id
          }
        },
        '$inc': {
          'unread': 1
        }
      }, multi: true, console.log


mongoose.model "GlobalNotification", Schema
