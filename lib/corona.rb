# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

module Corona

  def self.root
    ROOT
  end

  def self.path (*parts)
    File.join root, *parts.map(&:to_s)
  end

end

require "corona/volume"
require "corona/instance"
require "corona/api"
