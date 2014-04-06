require 'benchmark/ips'
require 'logger'

$:.unshift File.expand_path('../../lib', __FILE__)
require 'lines'

class FakeIO
  def write(*a)
  end
  alias syswrite write
end

globals = {
  app: 'benchmark',
  at: proc{ Time.now },
  pid: Process.pid,
}

at_exit{
  File.unlink "real_file.log"
}

EX = (raise "FOO" rescue $!)
DEV_NULL = File.open('/dev/null', 'w')

Benchmark.ips do |x|
  x.report "FakeIO write" do |n|
    Lines.use(FakeIO.new, globals)
    n.times{ Lines.log EX }
  end

  x.report "/dev/null write" do |n|
    Lines.use(DEV_NULL, globals)
    n.times{ Lines.log EX }
  end

  x.report "syslog write" do |n|
    Lines.use(Syslog, globals)
    n.times{ Lines.log EX }
  end

  x.report "real file" do |n|
    real_file = File.open('real_file.log', 'w')
    Lines.use(real_file, globals)
    n.times{ Lines.log EX }
  end

  x.report "real file logger" do |n|
    n.times{ Lines.logger.info "Ahoi this is a really cool option" }
  end

  x.report "traditioanl Logger" do |n|
    l = Logger.new(DEV_NULL)
    n.times{ l.info "This is a logger message" }
  end

  x.report "Logger with lines" do |n|
    l = Lines.logger
    n.times{ l.info "This is a logger message" }
  end
end
