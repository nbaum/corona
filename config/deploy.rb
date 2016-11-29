# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

set :application, "corona"
set :repo_url, "https://github.com/nbaum/corona.git"
set :use_sudo, nil

set :deploy_to, "/home/corona"

set :linked_dirs, %w[var]
set :linked_files, %w[.env]

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
