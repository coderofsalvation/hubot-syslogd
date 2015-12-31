logserver    = require 'syslogd-middleware'
syslogclient = require("syslog-client");
dns          = require 'dns'
nop          = () ->
protocol_get = (type,str) ->
  return str.split("://")[0]            if type is "protocol"
  return str.split("://")[1].split(":") if type is "server"

_ = 
  setname = (name,envelope) ->
    envelope.user.name = filtername         
    envelope.message.user.name = filtername 

module.exports = (robot) ->

  if not process.env.DEBUG? # *FIXME* syslog-client does a console.dir :(
    console.dir = nop

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
          modifiers = (if parts[2]? then parts[2] else null )
          if parts[1]? and String(data.message).match new RegExp(parts[1], modifiers )
            logserver.send_to_channels app, data, filtername, filter 
  ).bind({})

  logserver.send_to_channels = (app, data, filtername, filter) ->
    for output in filter.output
      # override username otherwise hubot wants to message the user too
      _.setname filtername, output if output.user?.name? and output.room?
      logserver.robot.reply output, String(data.message) 

  logserver.forward = (app, data, filtername, filter ) -> 
    for forward in filter.forward
      continue if forward == "udp://hostname:port"
      logserver.forwarder = {} if not logserver.forwarder
      if not logserver.forwarder[ forward ]?
        logserver.forward_syslog  forward, 
                                  protocol_get("server",str), 
                                  protocol_get("protocol",str)
      console.log "forward::"+forward if process.env.DEBUG?
      if logserver.forwarder[ forward ]?
        logserver.forwarder[ forward ].log data.message,       # *FIXME* please reflect syslog message
          facility: syslogclient.Facility.Local0               #
          severity: syslogclient.Severity.Informational        #
        , () -> #f=f
        
  logserver.forward_syslog = (forward,server,protocol) ->
    dns.resolve4 server[0], (err, addresses) ->
      return console.error "could not resolve: "+server[0] if err or not addresses.length
      console.log "creating "+protocol+" forwarder to '"+server[0]+"' on port "+server[1] if process.env.DEBUG?
      logserver.forwarder[ forward ] = syslogclient.createClient addresses[0],
        transport: (if protocol is "tcp" then syslogclient.Transport.Tcp else syslogclient.Transport.Udp),
        port: server[1]
      logserver.forwarder[ forward ].on 'error', -> console.dir arguments 

  commands = require('./commands')(robot)
  commands.init robot,logserver
  robot.brain.set 'foo','bar' # this triggers 'loaded' event ..WHY?
