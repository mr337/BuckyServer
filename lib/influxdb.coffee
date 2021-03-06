request = require('request')
dgram = require('dgram');

class Client
  constructor: (@config={}, @logger) ->
    do @init

  init: ->
    useUDP = @config.get('influxdb.use_udp').get() ? false

    @send = if useUDP then @sendUDP() else @sendHTTP()

  write: (metrics) ->
    @send @metricsJson metrics

  sendHTTP: ->
    host = @config.get('influxdb.host').get() ? 'localhost'
    port = @config.get('influxdb.port').get() ? 8086
    database = @config.get('influxdb.database').get() ? 'bucky'
    username = @config.get('influxdb.username').get() ? 'root'
    password = @config.get('influxdb.password').get() ? 'root'
    logger = @logger
    client = request.defaults
      method: 'POST'
      url: 'http://' + host + ':' + port + '/db/' + database + '/series'
      qs:
        u: username
        p: password

    (metricsJson) ->
      client form: metricsJson, (error, response, body) ->
        logger.log error if error

  sendUDP: ->
    host = @config.get('influxdb.host').get() ? 'localhost'
    port = @config.get('influxdb.port').get() ? 4444
    client = dgram.createSocket 'udp4'

    (metricsJson) ->
      message = new Buffer metricsJson

      client.send message, 0, message.length, port, host

  metricsJson: (metrics) ->
    data = []
    for key, desc of metrics
      [val, unit, sample] = @parseRow desc

      data.push
        name: key,
        columns: ['value'],
        points: [[parseFloat val]]

    JSON.stringify data

  parseRow: (row) ->
    re = /([0-9\.]+)\|([a-z]+)(?:@([0-9\.]+))?/

    groups = re.exec(row)

    unless groups
      @logger.log "Unparsable row: #{ row }"
      return

    groups.slice(1, 4)

module.exports = Client
