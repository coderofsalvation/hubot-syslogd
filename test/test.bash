#!/bin/bash 
SELF_PATH="$(dirname "$(readlink -f "$0")" )"
export PATH=$PATH:node_modules/.bin

[[ -n $ONLINE ]] && {
  export HUBOT_IRC_SERVER=irc.freenode.net
  export HUBOT_IRC_ROOMS=#hubot-syslog
  export HUBOT_IRC_NICK=hubot
  export HUBOT_IRC_UNFLOOD=true
  adapter="-a irc"
}
export DEBUG=1 ;
export FILE_BRAIN_PATH=$SELF_PATH

hubot ${adapter} -r $SELF_PATH/scripts
