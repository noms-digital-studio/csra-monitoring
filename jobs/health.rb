#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'httparty'
require 'ap'

#
### Global Config
#
# httptimeout => Number in seconds for HTTP Timeout. Set to ruby default of 60 seconds.
# ping_count => Number of pings to perform for the ping method
#
HTTP_TIMEOUT = 60
PING_COUNT = 10

#
# Check whether a server is Responding you can set a server to
# check via http request or ping
#
# Server Options
#   name
#       => The name of the Server Status Tile to Update
#   url
#       => Either a website url or an IP address. Do not include https:// when using ping method.
#   method
#       => http
#       => ping
#
# Notes:
#   => If the server you're checking redirects (from http to https for example)
#      the check will return false
#

servers = [
  { name: 'csra-app-mock', url: 'https://csra-mock.hmpps.dsd.io/health' },
  { name: 'csra-app-stage', url: 'https://csra-stage.hmpps.dsd.io/health'},
  { name: 'csra-app-prod', url: 'http://health-kick.hmpps.dsd.io/https/csra.service.hmpps.dsd.io' }
]

def gather_health_data(server)
  puts "requesting #{server[:url]}..."

  begin
    server_response = HTTParty.get(server[:url], headers: { 'Accept' => 'application/json' }, timeout: 5)
    ap server_response
    return server_response
  rescue HTTParty::Error => expection
    ap expection.class
    return { status: 'error', buildNumber: expection.class, checks: { db: "NA", viperRestService: "N/A" } }
  rescue StandardError => expection
    ap expection.class
    return { status: 'error', buildNumber: expection.class, checks: { db: "NA", viperRestService: "N/A" } }
  end
end

SCHEDULER.every '60s', first_in: 0 do |_job|
  servers.each do |server|
    result = gather_health_data(server)
    send_event(server[:name], result: result)
  end
end
