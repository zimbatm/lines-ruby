require 'spec_helper'
require 'lines/parser'

describe Lines::Parser do
  subject{ Lines::Parser }

  def expect_parse(str, opts={})
    expect(subject.parse str, opts)
  end

  it "can load stuff" do
    expect_parse('foo=bar bar=33').to eq("foo" => "bar", "bar" => 33)
  end

  it "handles max_depth items" do
    expect_parse('x=[...]').to eq("x" => ["..."])
    expect_parse('x={...}').to eq("x" => {"..." => ""})
  end

  it "handles unfinished lines" do
    expect_parse('x=foo ').to eq("x" => "foo")
  end

  it "treats missing value in a pair as an empty string" do
    expect_parse('x=').to eq("x" => "")
  end

  it "has non-greedy string parsing" do
    expect_parse('x="foo" bar="baz"').to eq("x" => "foo", "bar" => "baz")
  end

  it "unscapes quotes in quoted strings" do
    expect_parse("x='foo\\'bar'").to eq("x" => "foo'bar")
    expect_parse('x="foo\"bar"').to eq("x" => 'foo"bar')
  end

  it "doesn't parse literals when they are keys" do
    expect_parse("3=4").to eq("3" => 4)
  end

  it "handles some random stuff" do
    expect_parse("=").to eq("" => "")
    expect_parse('"\""=zzz').to eq('"' => "zzz")
  end

  it "knows how to restore iso time" do
    expect_parse("at=2013-07-12T21:33:47Z").to eq("at" => Time.at(1373664827).utc)
  end

  it "can symbolize the names" do
    expect_parse("foo=bar", symbolize_names: true).to eq(foo: "bar")
  end

  it "parses sample log lines" do
    expect_parse("commit=716f337").to eq("commit" => "716f337")

    line = <<LINE
at=2013-07-12T21:33:47Z commit=716f337 sql="SELECT FROM_UNIXTIME(UNIX_TIMESTAMP(created_at) - UNIX_TIMESTAMP(created_at)%(300)) as timestamp FROM `job_queue_logs` WHERE `job_queue_logs`.`account_id` = 'effe376baf553c590c02090abe512278' AND (created_at >= '2013-06-28 16:56:12') GROUP BY timestamp" elapsed=[31.9 ms]
LINE
    expect_parse(line).to eq(
      "at" => Time.at(1373664827).utc,
      "commit" => "716f337",
      "sql" => "SELECT FROM_UNIXTIME(UNIX_TIMESTAMP(created_at) - UNIX_TIMESTAMP(created_at)%(300)) as timestamp FROM `job_queue_logs` WHERE `job_queue_logs`.`account_id` = 'effe376baf553c590c02090abe512278' AND (created_at >= '2013-06-28 16:56:12') GROUP BY timestamp",
      "elapsed" => [31.9, "ms"],
    )
  end
end
