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
syslogclient = require("syslog-client");
dns       = require 'dns'

if not process.env.DEBUG? # *FIXME* syslog-client does a console.dir :(
  console.dir = () -> f=f 

##
# initialize syslog server and forwarder
##
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
          # send to channels
          for output in filter.output
            output.user.name = filtername if output.user?.name? and output.room?
            output.message.user.name = filtername if output.message.user?.name? and output.room?
            logserver.robot.reply output, String(data.message) 
          # Forward to remote services
          for forward in filter.forward
            continue if forward == "udp://hostname:port"
            logserver.forwarder = {} if not logserver.forwarder
            if not logserver.forwarder[ forward ]?
              _protocol = forward.split("://")[0]
              _server = forward.split("://")[1].split(":")
              ( (forward,server,protocol) ->
                dns.resolve4 server[0], (err, addresses) ->
                  if err or not addresses.length 
                    console.error "could not resolve: "+server[0]
                    return
                  console.log "creating "+protocol+" forwarder to '"+server[0]+"' on port "+server[1] if process.env.DEBUG?
                  logserver.forwarder[ forward ] = syslogclient.createClient addresses[0],
                    transport: (if protocol is "tcp" then syslogclient.Transport.Tcp else syslogclient.Transport.Udp),
                    port: server[1]
                  logserver.forwarder[ forward ].on 'error', -> console.dir arguments 
              )(forward,_server,_protocol)
            console.log "forward::"+forward if process.env.DEBUG?
            if logserver.forwarder[ forward ]?
              logserver.forwarder[ forward ].log data.message,       # *FIXME* please reflect syslog message
                facility: syslogclient.Facility.Local0               #
                severity: syslogclient.Severity.Informational        #
              , () -> #f=f
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
    console.dir msg.envelope if process.env.DEBUG?
    config = {filter:{}} if not config
    if not config.filter[ id ]?
      config.filter[ id ] =
        regex: regex
        output: [ msg.envelope ]
        forward: ["udp://hostname:port"]
      console.log JSON.stringify(config,null,2) if process.env.DEBUG?
      robot.brain.set 'syslog', config
    else 
      roomexist = false; userexist = false 
      for output in config.filter[ id ].output
        roomexist = true if output.room? and output.room == msg.envelope.room
        userexist = true if output.user?.name? and output.user.name == msg.envelope.user.name
      if not roomexist or not userexist 
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
        
  robot.brain.set 'foo','bar' # this triggers 'loaded' event ..WHY?

  return this


