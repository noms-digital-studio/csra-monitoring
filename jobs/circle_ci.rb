require 'httparty'
# require 'digest/md5'

httptimeout = 60
ping_count = 10

projects = [
  { user: 'noms-digital-studio', repo: 'csra-mvp', branch: 'master'},
  { user: 'noms-digital-studio', repo: 'csra-app', branch: 'master'},
]

def duration(time)
  secs  = time.to_int
  mins  = secs / 60
  hours = mins / 60
  days  = hours / 24

  if days > 0
    "#{days}d #{hours % 24}h ago"
  elsif hours > 0
    "#{hours}h #{mins % 60}m ago"
  elsif mins > 0
    "#{mins}m #{secs % 60}s ago"
  elsif secs >= 0
    "#{secs}s ago"
  end
end

def calculate_time(finished)
  finished ? duration(Time.now - Time.parse(finished)) : "--"
end

def translate_status_to_class(status)
  statuses = {
    'success' => 'passed',
      'fixed' => 'passed',
    'running' => 'pending',
     'failed' => 'failed'
  }
  statuses[status] || 'pending'
end

def build_data(project, auth_token)
  api_url = 'https://circleci.com/api/v1.1/project/github/%s/%s/tree/%s?circle-token=%s&limit=1'
  api_url = api_url % [project[:user], project[:repo], project[:branch], auth_token]
  api_response =  HTTParty.get(api_url, :headers => { "Accept" => "application/json" } )
  api_json = JSON.parse(api_response.body)
  return {} if api_json.empty?

  latest_build = api_json.select{ |build| build['status'] != 'queued' }.first
  # email_hash = Digest::MD5.hexdigest(latest_build['committer_email'])
  build_id = "#{latest_build['branch']}, build ##{latest_build['build_num']}"

  data = {
    build_id: build_id,
    repo: "#{project[:repo]}",
    branch: "#{latest_build['branch']}",
    time: "#{calculate_time(latest_build['stop_time'])}",
    state: "#{latest_build['status'].capitalize}",
    widget_class: "#{translate_status_to_class(latest_build['status'])}",
    committer_name: latest_build['committer_name'],
    commit_body: latest_build['subject'],
    # avatar_url: "http://www.gravatar.com/avatar/#{email_hash}"
  }
  return data
end

servers = [
    {name: 'csra-app-mock', url: 'http://csra-mock.hmpps.dsd.io/health', method: 'http'},
    {name: 'csra-app-stage', url: 'http://csra-stage.hmpps.dsd.io/health', method: 'http'},
]

SCHEDULER.every '10s', :first_in => 0  do
  projects.each do |project|
    data_id = "circle-ci-#{project[:user]}-#{project[:repo]}-#{project[:branch]}"
    data = build_data(project, ENV['CIRCLE_CI_TOKEN'])
    send_event(data_id, data) unless data.empty?
  end

  servers.each do |server|
    if server[:method] == 'http'
      begin
        uri = URI.parse(server[:url])

        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = httptimeout
        if uri.scheme == "https"
          http.use_ssl=true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        request = Net::HTTP::Get.new(uri.request_uri)
        if server[:auth] == true
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
      result = `ping -q -c #{ping_count} #{server[:url]}`
      if ($?.exitstatus == 0)
        result = 1
      else
        result = 0
      end
    end

    send_event(server[:name], result: result)
  end

end
