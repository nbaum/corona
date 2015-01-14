set :application, 'corona'
set :repo_url, 'corona@84.45.122.187:repo'

set :deploy_to, '/home/agent'

set :linked_dirs, %w{var}
set :linked_files, %w{.env}

set :keep_releases, 5

namespace :deploy do
  task :restart do
    on roles(:app), in: :sequence, wait: 2 do
      execute "tmux kill-session -t corona" rescue
      sleep 1
      execute "tmux new-session -d -s corona \"exec bash -lc '/home/agent/current/run'\""
    end
  end
end
