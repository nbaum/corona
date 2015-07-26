set :application, 'corona'
set :repo_url, 'ssh://git@fabric.orbitalinformatics.co.uk/diffusion/C/corona.git'
set :use_sudo, nil

set :deploy_to, '/home/corona'

set :linked_dirs, %w{var}
set :linked_files, %w{.env}

set :keep_releases, 5

namespace :deploy do
  task :restart do
    on roles :root do
      execute :cp, "~corona/current/corona.service", "/etc/systemd/system"
      execute :systemctl, "daemon-reload"
      execute :systemctl, "restart corona"
    end
  end
end
