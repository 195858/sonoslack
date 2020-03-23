#!./node_modules/.bin/iced

sonos = require('sonos')
request = require("request")
randomColor = require("randomcolor")
fs = require('fs')
request = require('request')
imgur = require('imgur')

download = (uri, filename, callback) ->
  f = (err, res, body) ->
    request(uri).pipe(fs.createWriteStream(filename)).on('close', callback)
  request.head(uri, f)


config = require('./config.json')

lastArtist = null
lastTitle = null
isBroke = false

mySonos = null
if config.sonosIpAddress == "detect"
  await(sonos.search(defer(mySonos)))
else
  mySonos = new sonos.Sonos(config.sonosIpAddress)

postToChat = (message) ->
  await(request.post({
    uri: config.slackIncomingWebHookUrl
    body: JSON.stringify(message)
  }, defer(err)))
  if err?
    console.error("Error posting to chat: #{err}")


checkSong = ->
  await(mySonos.currentTrack(defer(err, track)))
  if err? or not track?
    if not isBroke
      isBroke = true
      console.error("Error connecting to Sonos: #{err}")
      postToChat(text: "Error: #{err}")
  else if track.artist != lastArtist or track.title != lastTitle
    postSong(track)

postSong = (track) ->
  console.log(JSON.stringify(track))
  isBroke = false
  if track.albumArtURL != null && track.albumArtURL.startsWith("http")
    albumArtURL = track.albumArtURL
  else if track.albumArtURL != null
    albumArtURL = "http://"+config.sonosIpAddress+":1400"+track.albumArtURL
  lastArtist = track.artist
  lastTitle = track.title
  currentTitle = track.title
  if currentTitle.indexOf("?")>0
    currentTitle = track.title.substr(0, track.title.indexOf('?'))

  oneLiner = "#{track.artist} - #{currentTitle} - #{albumArtURL}"

  console.log(oneLiner)
  if albumArtURL
    await(download(albumArtURL, "./art.png", defer()))
    await(imgur.uploadFile("./art.png").then(defer(imgurData)))
  imageURL = "https://image.flaticon.com/icons/png/512/124/124711.png"
  if imgurData && imgurData.data
    imageURL = imgurData.data.link
  currentArtist = track.artist
  if !currentArtist
    currentArtist = currentTitle
  postOptions =
    link_names: 1
    attachments: [
      {
        fallback: oneLiner
        color: randomColor()
        fields: [
          {
            title: track.artist
            value: track.title
            short: true
          }
        ]
        image_url: imgurData.data.link
      }
    ]

  for key in ['username', 'icon_emoji']
    if config[key] then postOptions[key] = config[key]

  usersToNotify = []
  for user, favorites of config.favorites
    if track.artist in favorites
      usersToNotify.push(user)

  if usersToNotify.length > 0
    postOptions.text = "hi " + usersToNotify.join(", ")

  postToChat(postOptions)

checkSong()
setInterval(checkSong, 5000)
