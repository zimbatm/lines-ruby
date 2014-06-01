$:.unshift File.expand_path('../../lib', __FILE__)

require 'benchmark/ips'
require 'time'

$message = {
  "at" => Time.now.utc.iso8601,
  "pid" => Process.pid,
  "app" => File.basename($0),
  "pri" => "info",
  "msg" => "This is my message",
  "user" => {"t" => true, "f" => false, "n" => nil},
  "elapsed" => [55.67, 'ms'],
}

formatters = [
  ['lines', "Lines.dump($message)"],

  ['json/pure', "JSON.dump($message)"],
  ['oj', "Oj.dump($message)"],
  ['yajl', "Yajl.dump($message)"],
  
  ['msgpack', "MessagePack.dump($message)"],
  ['bson', "$message.to_bson"],
  ['tnetstring', "TNetstring.dump($message)"],
]

puts "%-12s %-5s %s" % ['format', 'size', 'output']
puts "-" * 25

Benchmark.ips do |x|
  x.compare!
  formatters.each do |(feature, action)|
    begin
      require feature

      data = eval action
      puts "%-12s %-5d %s" % [feature, data.size, data]

      x.report feature, action
    rescue LoadError
      puts "%-12s could not be loaded" % [feature]
    end
  end
end
