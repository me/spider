##
# Allows $stdout to be set via Thread.current[:stdout] per thread.
# By Eric Hodel, taken from http://blog.segment7.net/articles/2006/08/16/setting-stdout-per-thread

module ThreadOut

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
  
end

$stdout = ThreadOut