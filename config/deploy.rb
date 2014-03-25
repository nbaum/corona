# config valid only for Capistrano 3.1
lock '3.1.0'

set :application, 'corona'
set :repo_url, 'corona@84.45.122.187:repo'

set :deploy_to, '/home/corona'

set :linked_dirs, %w{var}

set :keep_releases, 5

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end
