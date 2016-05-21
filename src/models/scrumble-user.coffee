request = require 'request'
jwt = require 'jwt-simple'
moment = require 'moment'

unless process.env.GOOGLE_API_SECRET?
  console.warn 'The environment variable GOOGLE_API_SECRET is undefined. The Google authentication will not work'

config =
  TOKEN_SECRET: process.env.GOOGLE_API_SECRET

createJWT = (user) ->
  payload =
    sub: user.id
    iat: moment().unix()
    exp: moment().add(365, 'days').unix()
  jwt.encode payload, config.TOKEN_SECRET

generatePassword = (length) ->
  characters = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  result = (characters[Math.floor(Math.random() * characters.length)] for i in [1..length])
  result.join()

module.exports = (ScrumbleUser) ->

  ScrumbleUser.authorizeGoogle = (req, next) ->
    accessTokenUrl = 'https://accounts.google.com/o/oauth2/token'
    peopleApiUrl = 'https://www.googleapis.com/plus/v1/people/me/openIdConnect'

    unless req.body.code?
      err = new Error 'invalid_request'
      err.message = 'Missing required parameter: code'
      err.status = 400
      return next err

    params =
      code: req.body.code
      client_id: '605908567890-3bg3dmamghq5gd7i9sqsdhvoflef0qku.apps.googleusercontent.com'
      client_secret: config.TOKEN_SECRET
      redirect_uri: req.body.redirectUri
      grant_type: 'authorization_code'

    # Step 1. Exchange authorization code for access token.
    request.post accessTokenUrl,
      json: true
      form: params
    , (err, response, token) ->

      if token.error?
        err = new Error token.error
        err.message = token.error_description
        err.status = 400
        return next err

      accessToken = token.access_token
      headers = Authorization: 'Bearer ' + accessToken

      # Step 2. Retrieve profile information about the current user.
      request.get {
        url: peopleApiUrl
        headers: headers
        json: true
      }, (err, response, profile) ->

        if profile.error
          err = new Error 'Google API error'
          err.message = profile.error.message
          err.status = profile.error.code
          return next err

        # Step 3a. Link user accounts.
        if req.header('Authorization')
          ScrumbleUser.findOne
            where:
              remoteId: profile.sub
          , (err, existingUser) ->
            if existingUser
              err = new Error 'Google account already exists'
              err.message = 'There is already a Google account that belongs to you'
              err.status = 409
              return next err

            token = req.header('Authorization').split(' ')[1]
            payload = jwt.decode(token, config.TOKEN_SECRET)

            ScrumbleUser.findById payload.sub
            .then (user) ->
              console.log user
              if !user
                return res.status(400).send(message: 'User not found')
              user.google = profile.sub
              user.picture = user.picture or profile.picture.replace('sz=50', 'sz=200')
              user.displayName = user.displayName or profile.name
              user.save ->
                token = createJWT(user)
                res.send token: token
            .catch (err) ->
              console.log err
        else
          # Step 3b. Create a new user account or return an existing one.
          ScrumbleUser.findOne
            remoteId: profile.sub
          .then (existingUser) ->
            if existingUser
              return next null, token: createJWT(existingUser)

            user = new ScrumbleUser()
            user.remoteId = profile.sub
            user.email = profile.email
            user.username = profile.name
            user.password = generatePassword 100
            user.emailverified = profile.email_verified

            user.save()
            .then ->
              token = createJWT(user)
              next null, token: token
          .catch (err) ->
            next err

  ScrumbleUser.remoteMethod 'authorizeGoogle',
    accepts: [
      {
        arg: 'req'
        type: 'object'
        http:
          source: 'req'
      }
    ]
    returns:
      type: 'object'
      root: true
    http:
      verb: 'post'
      path: '/auth/google'
