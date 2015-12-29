# hubot-syslogd

flexible monitoring and aggregation of logs by using hubot as syslog server.

# Installation 

    npm install hubot-syslogd

# Usage:

Just invite hubot to a channel, and tell him which regex to watch:

    hubot syslog add errors /(error|ERROR)/

and then send a syslog message:
  
  $ logger -d -P 1338 -p local3.info hello this is foobar 

> Voila! It'll show up in the channel/query since it matched the regex :)

## Design

<img src="https://www.websequencediagrams.com/cgi-bin/cdraw?lz=dGl0bGUgSFVCT1QtU1lTTE9HIEZMT1cKCnN5c2xvZ2NsaWVudC0-aHVib3Q6IHB1c2ggVURQL1RDUCBsb2cgbWVzc2FnZXMKABwFAB8JcmVnZXggbWF0Y2g_AAwPZm9ybWF0ADEIACsNIGNoYW5uZWxzL3VzZXJzACcFd2FyZABVCG90aGVyIHNlcnZpY2UAFQogCm5vdGUgcmlnaHQgb2YgABcQYWxlcnRpbmcgYW5kIG1ldHJpY3MgXG51c2luZzogXG4qIHBhcGVydHJhaWxcbiogc3BsdW5rXG4qIGxvZ2dseQAeBWxvZ3N0YXNoXG4AXw8AghMHSACBPAVhY3RzIGFzIACCNwYAgSYFZXIK&s=napkin"/>

## sending JSON / Text formatting 

  $ logger -d -P 1338 -i -p local3.info -t FLOP '{"flop":"flap","template":"foobar {{indent:10:flop}}::{{indent:10:priority}}'"$(date)"'"}';

> See [syslogd-middleware](https://npmjs.org/syslogd-middleware) for more templating options

## All commands:

    hubot syslog                           - get overview of filters 
    hubot syslog config [variable] [value] - show/edit filter config
    hubot syslog add <id> [regex]          - add filter (or enable in current query/channel)
    hubot syslog remove <id>               - stop and remove a filter 

## A quick tryout

This plugin should work out of the box with your existing setup.
However, here's a quick tryout scenario:

    $ npm install hubot-syslog
    $ cd node_modules/hubot-syslog
    $ npm install --dev
    $ ONLINE=1 test/test.bash

This is just a testbot which should connect to the __#hubot-syslog__ channel of __irc.freenode.net__.

## Philosphy: a syslogd replacement

Hubot-syslog uses [syslog-middleware](https://npmjs.org/syslogd-middleware), therefore it is
highly extendable, syslog-compatible UDP/TCP loggingdaemon with use()-middleware support (like express).

__robot.logserver__ is your entrypoint to the `syslogd-middleware` module

    reuiqre('mymodule')(robot.logserver) // add inputs
    robot.logserver.use(...)             // add middleware/parsers
    robot.logserver.output.push (..)     // add outputs

for more info see the `syslog.coffee` initialisation in the top

