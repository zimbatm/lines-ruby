require 'benchmark/ips'

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

EX = (raise "FOO" rescue $!)

Benchmark.ips do |x|
  x.report "FakeIO write" do |n|
    Lines.use(FakeIO.new, globals)
    n.times{ Lines.log EX }
  end

  x.report "/dev/null write" do |n|
    dev_null = File.open('/dev/null', 'w')
    Lines.use(dev_null, globals)
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
end
