require 'httparty'

ci_projects = [
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

def gather_ci_data(project, auth_token)
  api_url = 'https://circleci.com/api/v1.1/project/github/%s/%s/tree/%s?circle-token=%s&limit=1'
  api_url = api_url % [project[:user], project[:repo], project[:branch], auth_token]
  api_response =  HTTParty.get(api_url, :headers => { "Accept" => "application/json" } )
  api_json = JSON.parse(api_response.body)
  return {} if api_json.empty?

  latest_build = api_json.select{ |build| build['status'] != 'queued' }.first
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
  }
end

SCHEDULER.every '30s', :first_in => 0  do
  ci_projects.each do |project|
    data_id = "circle-ci-#{project[:user]}-#{project[:repo]}-#{project[:branch]}"
    ci_data = gather_ci_data(project, ENV['CIRCLE_CI_TOKEN'])
    send_event(data_id, ci_data) unless ci_data.empty?
  end
end
