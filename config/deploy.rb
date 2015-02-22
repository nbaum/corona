set :application, 'corona'
set :repo_url, 'corona@84.45.122.187:repo'

set :deploy_to, '/home/corona'

set :linked_dirs, %w{var}
set :linked_files, %w{.env}

set :keep_releases, 5

namespace :deploy do
  task :restart do
    on roles(:sys), in: :sequence, wait: 2 do
      execute "systemctl restart corona"
    end
  end
end
