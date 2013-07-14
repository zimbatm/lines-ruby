$:.unshift File.expand_path('../../lib', __FILE__)
require 'lines'

module Kernel
  def bm(name = nil, &what)
    start = Time.now.to_f
    count = 0
    max = 0.5
    name ||= what.source_location.join(':')
    $stdout.write "#{name} : "
    while Time.now.to_f - start < max
      yield
      count += 1
    end
    $stdout.puts "%0.3f fps" % (count / max)
  end
end

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

Lines.use(FakeIO.new, globals)
bm "FakeIO write" do
  Lines.log EX
end

dev_null = File.open('/dev/null', 'w')
Lines.use(dev_null, globals)
bm "/dev/null write" do
  Lines.log EX
end

Lines.use(Syslog, globals)
bm "syslog write" do
  Lines.log EX
end

real_file = File.open('real_file.log', 'w')
Lines.use(real_file, globals)
bm "real file" do
  Lines.log EX
end

bm "real file logger" do
  Lines.logger.info "Ahoi this is a really cool option"
end

