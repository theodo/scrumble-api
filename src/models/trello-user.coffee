loopback = require 'loopback'
http = require('http')
OAuth = require('oauth').OAuth
url = require('url')

module.exports = (TrelloUser) ->
  oauth_secrets = {}

  requestURL = "https://trello.com/1/OAuthGetRequestToken"
  accessURL = "https://trello.com/1/OAuthGetAccessToken"
  authorizeURL = "https://trello.com/1/OAuthAuthorizeToken"
  appName = "Scrumble"

  key = "2dcb2ba290c521d2b5c2fd69cc06830e"
  secret = "38ddbedae05395a1a13323f60f5d95e0a40c7737938e449fe7ba669a0d72dae0"



  TrelloUser.login = (req, res, next) ->
    baseUrl = TrelloUser.app.get 'url'
    #Trello redirects the user here after authentication
    loginCallback = "#{baseUrl}api/TrelloUsers/callback"

    oauth = new OAuth(requestURL, accessURL, key, secret, "1.0", loginCallback, "HMAC-SHA1")

    oauth.getOAuthRequestToken (error, token, tokenSecret, results) =>
      oauth_secrets[token] = tokenSecret
      res.writeHead(302, { 'Location': "#{authorizeURL}?oauth_token=#{token}&name=#{appName}" })
      res.end()

  TrelloUser.handleResponse = (req, res, next) ->
    baseUrl = TrelloUser.app.get 'url'
    #Trello redirects the user here after authentication
    loginCallback = "#{baseUrl}api/TrelloUsers/callback"

    oauth = new OAuth(requestURL, accessURL, key, secret, "1.0", loginCallback, "HMAC-SHA1")

    query = url.parse(req.url, true).query

    token = query.oauth_token
    tokenSecret = oauth_secrets[token]
    verifier = query.oauth_verifier

    oauth.getOAuthAccessToken token, tokenSecret, verifier, (error, accessToken, accessTokenSecret, results) ->
      #in a real app, the accessToken and accessTokenSecret should be stored
      oauth.getProtectedResource("https://api.trello.com/1/members/me", "GET", accessToken, accessTokenSecret, (error, data, response) ->
        #respond with data to show that we now have access to your data
        res.end(data)
      )





  TrelloUser.remoteMethod 'login',
    accepts: [
      {
        arg: 'req'
        type: 'object'
        http:
          source: 'req'
      }
      {
        arg: 'res'
        type: 'object'
        http:
          source: 'res'
      }
    ]
    returns:
      root: true
      type: 'object'
    http:
      path: '/login'
      verb: 'GET'
    description: 'Login to Trello'

  TrelloUser.remoteMethod 'handleResponse',
    accepts: [
      {
        arg: 'req'
        type: 'object'
        http:
          source: 'req'
      }
      {
        arg: 'res'
        type: 'object'
        http:
          source: 'res'
      }
    ]
    returns:
      root: true
      type: 'object'
    http:
      path: '/callback'
      verb: 'GET'
    description: 'Callback'
