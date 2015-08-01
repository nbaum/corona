# encoding: utf-8
# Copyright (c) 2015 Nathan Baum

module Corona

  # The base class of all Corona errors
  Error = Class.new(StandardError)

  # Raised when attempting to manipulate an instance that isn't running.
  NotRunning = Class.new(Error)

end
