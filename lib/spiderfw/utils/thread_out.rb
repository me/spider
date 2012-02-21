##
# Allows $stdout to be set via Thread.current[:stdout] per thread.
# By Eric Hodel, taken from http://blog.segment7.net/articles/2006/08/16/setting-stdout-per-thread

# Thread local $stdout.
module ThreadOut #:nodoc:

  ##
  # Writes to Thread.current[:stdout] instead of STDOUT if the thread local is
  # set.

  def self.write(stuff)
    if Thread.current[:stdout] then
      Thread.current[:stdout].write stuff 
    else
      STDOUT.write stuff
    end
  end
  
  def self.<<(stuff)
      self.write(stuff)
  end
  
  def self.output_to(io)
      prev_out = Thread.current[:stdout]
      if block_given?
          Thread.current[:stdout] = io
          yield
          Thread.current[:stdout] = prev_out
          io.rewind
      else
          Thread.current[:stdout] = io
          return prev_out
      end
  end
  
  def output_to(io, &proc)
      self.class.output_to(io, &proc)
  end
  
end