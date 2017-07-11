#!/usr/bin/env ruby
require 'net/http'
require 'uri'

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
    {name: 'csra-app-mock', url: 'https://csra-mock.hmpps.dsd.io/health', method: 'http'},
    {name: 'csra-app-stage', url: 'https://csra-stage.hmpps.dsd.io/health', method: 'http'},
    {name: 'csra-app-prod', url: 'http://health-kick.hmpps.dsd.io/https/csra.service.hmpps.dsd.io', method: 'http'},
]

def gather_health_data(server)
    result = 0
    puts "requesting #{server[:url]}..."
    if server[:method] == 'http'
        begin
            uri = URI.parse(server[:url])

            http = Net::HTTP.new(uri.host, uri.port)
            http.read_timeout = HTTP_TIMEOUT
            if uri.scheme == "https"
                http.use_ssl = true
            end

            request = Net::HTTP::Get.new(uri.request_uri)
            if server[:auth]
                basic_auth = ENV['BASIC_AUTH']
                request.basic_auth basic_auth.split(':').first, basic_auth.split(':').last
            end

            response = http.request(request)

            if response.code == "200"
                result = 1
            else
                result = 0
            end
        rescue Timeout::Error
            result = 0
        rescue Errno::ETIMEDOUT
            result = 0
        rescue Errno::EHOSTUNREACH
            result = 0
        rescue Errno::ECONNREFUSED
            result = 0
        rescue SocketError => e
            result = 0
        end
    elsif server[:method] == 'ping'
        result = `ping -q -c #{PING_COUNT} #{server[:url]}`
        if $?.exitstatus == 0
            result = 1
        else
            result = 0
        end
    end
    puts "Result from #{server[:url]} is #{result}"
    result
end

SCHEDULER.every '60s', :first_in => 0 do |job|
  servers.each do |server|
    result = gather_health_data(server)
    send_event(server[:name], result: result)
  end
end
