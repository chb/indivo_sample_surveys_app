class NullLogger
  # Class that implements the most popular parts of the Logger API, but just
  # throws away the messages.  Allows us to log things without having to
  # check if @logger is set first.

  def initialize(*args) end
  def debug(msg) end
  def info(msg) end
  def warn(msg) end
  def error(msg) end
  def fatal(msg) end
  def unknown(msg) end
end
