> deprecated in favor of log4js and/or netdata

Pre-massage/route log messages before sending them to Splunk/Papertrail/Logsene etc.

![Build Status](https://travis-ci.org/coderofsalvation/hubot-syslogd.svg?branch=master)

<img src="https://www.websequencediagrams.com/cgi-bin/cdraw?lz=dGl0bGUgSFVCT1QtU1lTTE9HIEZMT1cKCnN5c2xvZ2NsaWVudC0-aHVib3Q6IHB1c2ggVURQL1RDUCBsb2cgbWVzc2FnZXMKABwFAB8JcmVnZXggbWF0Y2g_AAwPZm9ybWF0ADEIACsNIGNoYW5uZWxzL3VzZXJzACcFd2FyZABVCG90aGVyIHNlcnZpY2UAFQogCm5vdGUgcmlnaHQgb2YgABcQYWxlcnRpbmcgYW5kIG1ldHJpY3MgXG51c2luZzogXG4qIHBhcGVydHJhaWxcbiogc3BsdW5rXG4qIGxvZ2dseQAeBWxvZ3N0YXNoXG4AXw8AghMHSACBPAVhY3RzIGFzIACCNwYAgSYFZXIK&s=napkin"/>


# Installation 

    npm install hubot-syslogd

> Overridable Environment variables

* SYSLOG_HOST=127.0.0.1   
* SYSLOG_UDP_PORT=1338
* SYSLOG_TCP_PORT=1337   

## Usage:

First tell hubot which regex to watch by typing to hubot:

    hubot syslog add errors /(error|fail)/gi 
   
Then invite hubot to a channel, or add him to a private chat, and type this:

    hubot syslog enable errors

and then send a UDP+TCP syslog message using a [PHP](https://github.com/coderofsalvation/syslog-flexible) / [JS](https://npmjs.org/syslog-client) syslog client, or on unix:
  
    $ logger -d --rfc3164 -n localhost -P 1338 -p local3.info hello this is an error 
    $ logger -T --rfc3164 -n localhost -P 1339 -p local3.info hello this is an error  

> Voila! It'll show up in the chat since it matched the regex :)

    [15:29] <hubot> errors: hello this is an error 

> See [syslog-middleware](https://github.com/coderofsalvation/syslog-middleware/) on how to send syslog using nodejs [winston](https://npmjs.org/winston), or simply forward
your console using [sysconsole](@divine/sysconsole):

```javascript
import { SysConsole } from '@divine/sysconsole';
SysConsole.replaceConsole({ loghost: 'localhost', logport:1339,   facility: 'local0',  title: 'MySweetApp',  showFile: true,  syslogTags: true, showFunc:true,   highestLevel: 'info',  tcpTimeout:1000 })
console.log("hoi error") 
console.warn("hoi error") 
```

## Email alerts anyone?

just get a papertrail account and forward 'errors' to papertrail/Splunk etc, by sending this to hubot:

    hubot syslog config filter.errors.forward.0 udp://yourhost.papertrailapp.com:yourport

And configure alerts in their dashboards.

## sending JSON / Text formatting 

    $ logger -d -P 1338 -i -p local3.info -t FLOP 'foobar {{indent:10:priority}}::ok'
    $ logger -d -P 1338 -i -p local3.info -t FLOP '{"flop":"flap","template":"foobar {{indent:10:flop}}::{{indent:10:priority}} errors"}'

will produce nice-aligned output in the chat:

    [15:29] <hubot> errors: foobar 158        ::ok 
    [15:29] <hubot> errors: foobar flap       ::159        error 

This allows more readable logs, and/or pretty forwarded messages (to papertrail/slack/splunk etc)

> See [syslogd-middleware](https://npmjs.org/syslogd-middleware) for more templating options

## All commands:

   hubot syslog                           - get overview of filters 
   hubot syslog config [variable] [value] - show/edit filter config
   hubot syslog add <id> [regex]          - add filter
   hubot syslog remove <id>               - stop and remove a filter 
   hubot syslog enable <id>               - start monitoring in current channel/query 
   hubot syslog disable <id>              - stop monitoring in current channel/query 

## Forward messages / Backup / Files

Additionaly you could forward the logmessages to:

* a rsyslog unix daemons (which can save to files, including logrotate etc)
* a SaaS logservices (splunk/papertrail etc)
    
Just add their syslog-serverinfo like this:    
    
    hubot syslog config filter.errors.forward.0 udp://localhost:514 
    hubot syslog config filter.errors.forward.1 tcp://someserver:567

## Quick tryout

This plugin should work out of the box with your existing setup.
However, here's a quick tryout scenario:

    $ npm install hubot-syslogd
    $ cd node_modules/hubot-syslogd
    $ npm install --dev
    $ ONLINE=1 test/test.bash

This is just a testbot which should connect to the __#hubot-syslog__ channel of __irc.freenode.net__.

## Philosphy: a syslogd replacement

> (NG-/R)Syslog is great, but its configuration can become herculean quite fast.

Hubot-syslog uses [syslog-middleware](https://npmjs.org/syslogd-middleware), therefore it is
highly extendable, syslog-compatible UDP/TCP loggingdaemon with use()-middleware support (like express).

__robot.logserver__ is your entrypoint to the `syslogd-middleware` module

    reuiqre('mymodule')(robot.logserver) // add inputs
    robot.logserver.use(...)             // add middleware/parsers
    robot.logserver.output.push (..)     // add outputs

for more info see the `syslog.coffee` initialisation in the top

