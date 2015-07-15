
require 'yaml'
require 'octokit'

###########################################################################
# Load configuration parameters.
###########################################################################

global_config = YAML.load_file('/etc/latcraft.yml')

###########################################################################
# Configure GitHub client.
###########################################################################

# Octokit.auto_paginate = true
# github = Octokit::Client.new(:access_token => global_config['github_access_token'])
# github_org = global_config['github_organization']


###########################################################################
# Job's body.
###########################################################################

SCHEDULER.every '1m', :first_in => 0 do |job|
  # Collect current organization statistics
  # github.org_issues(github_org, :state => 'open')
  # github.org_repositories(github_org)
  # TODO: extract full number of branches
  # TODO: extract full number of commits
  # TODO: extract today's number of commits
  # TODO: extract weeks's number of commits

end

SCHEDULER.every '1d', :first_in => 0 do |job|
  # Collect member information
  # TODO: extract list of star gazers for each repo
  # TODO: extract list of committers for each repo
  # TODO: extract list of watchers for each repo
  # TODO: extract list of pull requesters
  # TODO: extract list of issue commenters
  # TODO: extract each repo traffic data
end




