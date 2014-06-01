require 'spec_helper'
require 'lines/generator'

describe Lines::Generator do
  def expect_dump(obj, opts={})
    expect(subject.generate obj, opts)
  end

  it "can dump stuff" do
    expect_dump(foo: "bar", bar: 33).to eq('foo=bar bar=33')
  end

  it "handles max_depth items" do
    expect_dump({x: [444]}, max_nesting: 1).to eq('x=[...]')
    expect_dump({x: {y: 444}}, max_nesting: 1).to eq('x={...}')
  end

  it "treats missing value in a pair as an empty string" do
    expect_dump(x: '').to eq("x=")
  end

  it "escapes quotes in quoted strings" do
    expect_dump(x: "foo'bar").to eq("x=\"foo'bar\"")
    expect_dump(x: 'foo"bar').to eq("x='foo\"bar'")
  end

  it "doesn't parse literals when they are keys" do
    expect_dump(3 => 4).to eq("3=4")
  end

  it "handles some random stuff" do
    expect_dump("" => "").to eq("=")
    expect_dump('"' => 'zzz').to eq('\'"\'=zzz')
  end

#   it "parses sample log lines" do
#     expect_load("commit=716f337").to eq("commit" => "716f337")

#     line = <<LINE
# at=2013-07-12T21:33:47Z commit=716f337 sql="SELECT FROM_UNIXTIME(UNIX_TIMESTAMP(created_at) - UNIX_TIMESTAMP(created_at)%(300)) as timestamp FROM `job_queue_logs` WHERE `job_queue_logs`.`account_id` = 'effe376baf553c590c02090abe512278' AND (created_at >= '2013-06-28 16:56:12') GROUP BY timestamp" elapsed=[31.9 ms]
# LINE
#     expect_load(line).to eq(
#       "at" => Time.at(1373664827).utc,
#       "commit" => "716f337",
#       "sql" => "SELECT FROM_UNIXTIME(UNIX_TIMESTAMP(created_at) - UNIX_TIMESTAMP(created_at)%(300)) as timestamp FROM `job_queue_logs` WHERE `job_queue_logs`.`account_id` = 'effe376baf553c590c02090abe512278' AND (created_at >= '2013-06-28 16:56:12') GROUP BY timestamp",
#       "elapsed" => [31.9, "ms"],
#     )
#   end
end
