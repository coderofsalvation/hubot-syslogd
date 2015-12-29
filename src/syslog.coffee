# Description:
#   interface to syslog 
#
# Dependencies: easy-table, syslogd-middleware
#
# Commands:
#   hubot syslog                           - get overview of filters 
#   hubot syslog config [variable] [value] - show/edit filter config
#   hubot syslog add <id> [regex]          - add filter (or enable filter in channel/query) 
#   hubot syslog remove <id>               - stop and remove a filter 
#
# Author:
#   Leon van Kammen
#
  
ascii     = require('easy-table')
flat      = require('flat')
unflat    = require('flat').unflatten
logserver = require 'syslogd-middleware'

# initialize syslog server
logserver.config = false
require('syslogd-middleware/src/input/syslog')(logserver)
logserver.use require('syslogd-middleware/src/parser/syslog')
logserver.use require('syslogd-middleware/src/parser/brown')
logserver.outputs.push require 'syslogd-middleware/src/output/stdout' if process.env.DEBUG?
logserver.outputs.push ( (app,data) ->
  if logserver?.config?.filter?
    for filtername,filter of logserver.config.filter
      if filter.regex?
        parts = filter.regex.split("/")
        if parts[1]? and String(data.message).match( new RegExp(parts[1]) )
          logserver.robot.reply output, String(data.message) for output in filter.output
).bind({})

module.exports = (robot) ->

  config = false
  syslog = 
    usage:
      add: """Usage: syslog add <id> <regex>

           """      

  format = (data,formatstyle) ->
    if formatstyle is "ascii"
      a = new ascii
      for row in data
        for key,value of row 
          value = '{}' if typeof value is 'object'
          a.cell( key, value ) 
        a.newRow()
      return a.toString()
    if formatstyle is 'flat'
      rows = [] ; rows.push {variable:k,value:v} for k,v of flat(data)
      return "\n"+format rows, "ascii" 
      

  merge = (source, obj, clone) ->
    return source if source == null
    for prop of obj
      v = obj[prop]
      if source[prop] != null and typeof source[prop] == 'object' and typeof obj[prop] == 'object'
        @merge source[prop], obj[prop]
      else
        if clone
          source[prop] = @clone
        else
          source[prop] = obj[prop]
    source

  # Persist reminders to the brain, on save event
  robot.brain.on 'save', ->
    if config
      robot.brain.data.syslog = config

  robot.brain.on 'loaded', -> 
    config = robot.brain.get('syslog')
    robot.logserver = logserver
    logserver.robot = robot
    logserver.config = config

  robot.respond /syslog$/i, (msg) ->
    filters = []
    for k,v of config.filter
      outputs = []
      for output in v.output
        outputs.push output.message.room  if output.message?.room?
        outputs.push output.user.name     if output.user?.name?
      filters.push
        id: k
        regex: v.regex
        outputs: outputs.join(",")
        forward: v.forward.join(",")
    msg.send "\n"+format filters, 'ascii' 
  
  robot.respond /syslog add$/i, (msg) ->
    msg.send( syslog.usage.add )

  robot.respond /syslog add (.*)/i, (msg) ->
    args = msg.match[1].split(" ")
    id = args[0].replace(/\./g,'-')
    regex = args[1]
    #msg.envelope.message.room
    console.dir msg.envelope
    config = {filter:{}} if not config
    if not config.filter[ id ]?
      config.filter[ id ] =
        regex: regex
        output: [ msg.envelope ]
        forward: []
      robot.brain.set 'syslog', config
    else 
      add = true
      for output in config.filter[ id ].output
        add = false if output.room? and output.room == msg.envelope.room
        add = false if output.user?.name? and output.user.name == msg.envelope.user.name
      if add
        config.filter[ id ].output.push msg.envelope 
        msg.send "added to filter '"+id+"'"
      else
        msg.send "already added"

  robot.respond /syslog remove (.*)/i, (msg) ->
    args = msg.match[1].split(" ")
    return msg.send(syslog.usage.setfilter) if args.length < 1
    id = args.shift()
    if config.filter[ id ]?
      delete config.filter[ id ]
      robot.brain.set 'syslog', config
      msg.send "'#{id}' removed"
    else msg.send "id '#{id}' does not exist"
  
  robot.respond /syslog config$/i, (msg) ->
    msg.send format config, 'flat' 
  
  robot.respond /syslog config (\S+)$/i, (msg) ->
    cfg = flat config
    variable = msg.match[1]
    rows = [] 
    for k,v of cfg
      rows.push {variable:k,value:v} if k.search(variable) != -1
    msg.send "\n"+format rows, "ascii" 

  robot.respond /syslog config (\S+) (.*)/i, (msg) ->
    variable = msg.match[1]
    value = msg.match[2]
    cfg = flat(config)
    if cfg[ variable ]?
      if not value 
        return msg.send ( if typeof cfg[ variable ] is "string" then cfg[ variable ] else format cfg[ variable ], 'flat' )
      else
        if value is "null"
          delete cfg[ variable ]
        else 
          cfg[ variable ] = value 
    else 
      cfg[ variable ] = value
    robot.brain.set 'syslog', unflat(cfg)
    msg.send "'#{variable}' set to '#{value}'"
  
  # Catch-all listener to mute responses
  #robot.hear /(.*)$/i, {id: "hubot-syslog"}, (msg) ->
  #  console.dir msg
  #  if mute_all is false and mute_channels.indexOf(process.env.HUBOT_MUTE_ROOM_PREFIX + msg.message.room) == -1
  #    return
  #  if msg.match[1].indexOf('mute') != -1
  #    return

  #  #msg.finish()

  #  #if msg.match[0].toLowerCase().indexOf(robot.name.toLowerCase()) != 0
  #    return

  #  #reason = if mute_all is true then 'All channels are muted' else "Channel #{process.env.HUBOT_MUTE_ROOM_PREFIX}#{msg.message.room} is muted"
  #  #if !mute_explain[msg.message.room]?
  #  #  msg.send 'This channel is currently muted because: ' + reason
  #  #  mute_explain[msg.message.room] = true
  #  #  delay 300000, ->
  #  #    delete mute_explain[msg.message.room]

  #mute_listener = robot.listeners.pop()
  #robot.listeners.unshift(mute_listener)
        
  robot.brain.set 'foo','bar' # this triggers 'loaded' event ..WHY?

  return this


