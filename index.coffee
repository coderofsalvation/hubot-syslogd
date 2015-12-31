fs = require 'fs'
path = require 'path'

module.exports = (robot, scripts) ->
  return require('./src/syslog')(robot)
