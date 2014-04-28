# config valid only for Capistrano 3.2
lock '3.2.0'

set :application, 'corona'
set :repo_url, 'corona@84.45.122.187:repo'

set :deploy_to, '/home/corona'

set :linked_dirs, %w{var}

set :keep_releases, 5
