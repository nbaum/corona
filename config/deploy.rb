# config valid only for Capistrano 3.2
lock '3.2.1'

set :application, 'corona'
set :repo_url, 'corona@84.45.122.187:repo'

set :deploy_to, '/home/corona'

set :linked_dirs, %w{var}

set :keep_releases, 5

namespace :deploy do
  task :restart do
    on roles(:app), in: :sequence, wait: 2 do
      execute "tmux kill-session -t corona" rescue
      execute "tmux new-session -d -s corona /home/corona/run"
    end
  end
end

