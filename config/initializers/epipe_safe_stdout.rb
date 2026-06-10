# Sidekiq often runs without a TTY; writes to STDOUT/STDERR raise Errno::EPIPE when the pipe is closed.
module EpipeSafeIO
  def write(*args)
    super
  rescue Errno::EPIPE
    0
  end

  def writev(*args)
    super
  rescue Errno::EPIPE
    0
  end
end
