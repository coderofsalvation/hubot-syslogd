# Description:
#   interface to syslog 
#
# Dependencies: easy-table, syslogd-middleware
#
# Commands:
#   hubot syslog                           - get overview of filters 
#   hubot syslog config [variable] [value] - show/edit filter config
#   hubot syslog add <id> [regex]          - add filter
#   hubot syslog remove <id>               - stop and remove a filter 
#   hubot syslog enable <id>               - start monitoring in current channel/query 
#   hubot syslog disable <id>              - stop monitoring in current channel/query 
#
# Author:
#   Leon van Kammen
#

ascii     = require('easy-table')
flat      = require('flat')
unflat    = require('flat').unflatten
_         =
  array_remove: (arr,value) -> (x for x in arr when x != value )
  isroom: (envelope) ->( envelope?.room? and envelope.room.length and ( envelope.room != envelope.user.name )  )

module.exports = (robot) ->

  console.log "ja"
  config = false
  syslog = 
    usage:
      add: """Usage: syslog add <id> <regex>"""

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

  get_config_options = (cfg,recursiondepth) ->
    lines = format( cfg, 'flat' ).split("\n")
    return ( line for line in lines when line.split(".").length < recursiondepth )

  # Persist reminders to the brain, on save event
  robot.brain.on 'save', ->
    if config
      robot.brain.data.syslog = config

  enable = (id,msg) ->
    roomexist = false; userexist = false 
    if config?.filter?[ id ]?
      for output in config.filter[ id ].output
        roomexist = true if output.room? and output.room == msg.envelope.room
        userexist = true if not _.isroom(msg.envelope) and output.user?.name? and output.user.name == msg.envelope.user.name
      if not roomexist or not userexist 
        config.filter[ id ].output.push msg.envelope 
        msg.send "enabled '"+id+"' for "+ msg.envelope.room || msg.envelope.user.name
      else
        msg.send "already enabled"
    else msg.send "filter '"+id+"' does not exist..use 'syslog add' first"

  disable = (id,msg) ->
    roomexist = false; userexist = false 
    if config?.filter?[ id ]?
      deleted = false
      for output in config.filter[ id ].output
        matches_room = ( output.room? and output.room == msg.envelope.room )
        matches_user = ( not _.isroom(msg.envelope) and output.user?.name? and output.user.name == msg.envelope.user.name )
        if matches_room or matches_user
          config.filter[ id ].output = _.array_remove config.filter[ id ].output, output 
          deleted = true
      if deleted 
        msg.send "disabled '"+id+"' for "+ msg.envelope.room || msg.envelope.user.name
    else msg.send "filter '"+id+"' does not exist..use 'syslog add' first"

  robot.respond /syslog$/i, (msg) ->
    filters = []
    if config?.filter?
      for k,v of config.filter
        outputs = []
        for output in v.output
          outputs.push output.message.room  if _.isroom(output) and output.message?.room?
          outputs.push output.user.name     if not _.isroom(output) and output.user?.name?
        filters.push
          id: k
          regex: v.regex
          outputs: outputs.join(",")
          forward: v.forward.join(",")
      msg.send "\n"+format filters, 'ascii' 
    else msg.send "empty..please use 'syslog add' to add filters"
  
  robot.respond /syslog add$/i, (msg) ->
    msg.send( syslog.usage.add )

  robot.respond /syslog add (.*)/i, (msg) ->
    args = msg.match[1].split(" ")
    id = args[0].replace(/\./g,'-')
    regex = args[1]
    console.dir msg.envelope if process.env.DEBUG?
    config = {filter:{}} if not config
    if not config.filter[ id ]?
      config.filter[ id ] =
        regex: regex
        output: []
        forward: ["udp://hostname:port"]
      console.log JSON.stringify(config,null,2) if process.env.DEBUG?
      msg.send "ok added, run 'syslog [config filter."+id+"]' to view [or configure]"
      robot.brain.set 'syslog', config
    else msg.send "already exists"

  robot.respond /syslog enable (\S+)$/i, (msg) ->
    id = msg.match[1]
    enable id,msg
    console.dir config
  
  robot.respond /syslog disable (\S+)$/i, (msg) ->
    id = msg.match[1]
    disable id,msg
    console.dir config

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
    return msg.send( get_config_options(config,6).join "\n" )
  
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
        if typeof cfg[ variable ] is "string"
          return msg.send cfg[ variable ] 
        else 
          # lets only print options with a recursion depth of 5
          return msg.send( get_config_options( cfg[ variable ],6).join "\n" ) 
      else
        if value is "null"
          delete cfg[ variable ]
        else 
          cfg[ variable ] = value 
    else 
      cfg[ variable ] = value
    robot.brain.set 'syslog', unflat(cfg)
    msg.send "'#{variable}' set to '#{value}'"
  
  return  {
    init: (robot,logserver) ->
      robot.brain.on 'loaded', -> 
        config = robot.brain.get('syslog')
        logserver.robot = robot
        logserver.config = config
  }

