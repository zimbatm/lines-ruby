module Lines
  class RollingFile
    attr_reader :path, :io

    PERIOD_TO_SECONDS = {
      day: 24 * 60 * 60,
      week: 7 * 24 * 60 * 60,
      month: 30 * 24 * 60 * 60
    }

    # every: roll every (day | week | month)
    # keep:  how many files to keep
    def initialize(path, opts={})
      @path = File.expand_path(path)
      @interval = PERIOD_TO_SECONDS[opts.fetch(:every, :day).to_sym] || PERIOD_TO_SECONDS.values.first
      @mutex = Mutex.new
      @keep = opts[:keep] || 7

      reopen_file
    end

    def write(string)
      @io.syswrite string
      try_rotate if need_rotation?
    end

    protected

    def reopen_file
      (@io.close rescue nil) if @io

      io = File.open(@path, 'w')
      ctime = io.stat.ctime
      @io, @ctime = io, ctime
    end

    def need_rotation?
      Time.now - @ctime > @interval
    end

    def try_rotate
      return unless @mutex.try_lock
      _rotate_file
    end

    # FIXME: Don't know what happens if nothing is written during interval x 2
    #        or more.
    def _rotate_file
      return unless @io.flock(File::LOCK_EX || File::LOCK_NB)
      return unless need_rotation? # Just double-checking to be sure
      ctime = File.ctime(@path) rescue 0

      # Don't do this if the ctime has changed, it means another process has
      # already rotated the file (the flock is then on the old moved file).
      if ctime == @ctime
        # Shelve the current log file
        old_path = @path + @ctime.strftime('.%Y-%m-%d')
        File.rename(@path, old_path)

        # Remove old files
        old_logs = Dir[@path + '.*']
        if old_logs.size > @keep
          old_logs.sort[0..@keep-1].each do |file|
            File.unlink(file)
          end
        end
      end

      reopen_file
    ensure
      @mutex.unlock
    end
  end
end
