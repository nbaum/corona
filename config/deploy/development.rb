# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

set :rvm_roles, [:app]

role :root, %w[
  root@
  root@10.2.12.4
  root@10.2.12.100
  root@10.2.12.101
], no_release: true

role :app, %w[
  corona@10.2.12.4
  corona@10.2.12.100
  corona@10.2.12.101
]
