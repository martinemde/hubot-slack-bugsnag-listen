# Description:
#   Listen for urls from bugsnag and display bug details in a Slack attachment
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_BUGSNAG_TOKEN
#
# Commands:
#   Paste a bugsnag link in the presence of hubot
#   Example (fake) link: https://bugsnag.com/org-name/app_id/errors/5623a71f8203f6a650d9e2dc?filters%5Bevent.since%5D%5B%5D=30d
#
# Author:
#   martinemde

module.exports = (robot) ->
  token = process.env.HUBOT_BUGSNAG_TOKEN

  # Check for required config
  apiTokenMissing = (msg) ->

  robot.hear /bugsnag.com\/[-_\w]+\/([-_\w]+)\/errors\/([0-9a-z]+)\??/i, id: 'bugsnag-listen', (msg) ->
    app_id = msg.match[1]
    error_id = msg.match[2]
    room = msg.message.room

    unless process.env.HUBOT_BUGSNAG_TOKEN?
      return msg.send "BugSnag Token Missing: Ensure that HUBOT_BUGSNAG_TOKEN is set."

    msg.http("https://api.bugsnag.com/errors/#{error_id}").headers("Authorization": "token #{token}").get() (err, res, body) ->
      return msg.send "Bugsnag Error: #{err}" if err
      return if res.statusCode == 404 # Not found

      try
        bugsnag = JSON.parse(body)
      catch e
        return msg.send "Error parsing bugsnag body: #{e}"

      if bugsnag.resolved
        color = "good"
        resolved = "Resolved"
      else
        color = "danger"
        resolved = "Unresolved"


      fields = [
        {
          title: resolved,
          value: "#{bugsnag.occurrences} Occurrences",
          short: true
        }
      ]

      if bugsnag.release_stages?.production?
        fields.push
          title: "Production"
          value: "#{bugsnag.release_stages.production} Occurrences",
          short: true
      else if bugsnag.release_stages?.staging?
        fields.push
          title: "Staging"
          value: "#{bugsnag.release_stages.staging} Occurrences",
          short: true

      robot.emit 'slack-attachment',
        message:
          room: msg.message.room
        content:
          fallback: "#{bugsnag.class}: #{bugsnag.last_message} #{bugsnag.last_context}"
          pretext: "[#{app_id}] Bugsnag Error"
          title: "#{bugsnag.class}: #{bugsnag.last_context}"
          title_link: bugsnag.html_url
          text: bugsnag.last_message
          color: color
          fields: fields
    
