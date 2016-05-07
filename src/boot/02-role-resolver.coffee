module.exports = (server) ->

  Role = server.models.Role

  Role.isAdmin = (token, next) ->
    return next(null, false) unless token?
    server.models.User.find
      where:
        email:
          inq: ['nicolasg@theodo.fr']
    , (err, admins) ->
      return next(err, token.userId in (admin.id for admin in admins))

  Role.registerResolver 'admin', (role, context, next) ->
    Role.isAdmin(context?.accessToken, next)
