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

$data = {}

formatters = [
  ['lines', "Lines.dump($message)", "Lines.load($data[:lines])"],

  ['json', "$message.to_json", "JSON.load($data[:json])"],
  ['oj', "Oj.dump($message)", "Oj.load($data[:oj])"],
  ['yajl', "Yajl.dump($message)", "Yajl.load($data[:yajl])"],
  
  ['msgpack', "MessagePack.dump($message)", "MessagePack.load($data[:msgpack])"],
  ['bson', "$message.to_bson", "???"],
  ['tnetstring', "TNetstring.dump($message)", "TNetstring.load($data[:tnetstring])"],
]

Benchmark.ips do |x|
  x.compare!
  formatters.each do |(feature, dumper, loader)|
    begin
      require feature

      $data[feature.to_sym] = eval dumper
      #puts "%-12s %-5d %s" % [feature, data.size, data]

      msg = eval loader

      if $message != msg
        p $message, msg
      end

      x.report feature, loader
    rescue LoadError
      puts "%-12s could not be loaded" % [feature]
    end
  end
end
