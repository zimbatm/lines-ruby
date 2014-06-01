require 'spec_helper'
require 'lines/parser'

describe Lines::Parser do
  subject{ Lines::Parser }

  def expect_load(str, opts={})
    expect(subject.parse str, opts)
  end

  it "can load stuff" do
    expect_load('foo=bar bar=33').to eq("foo" => "bar", "bar" => 33)
  end

  it "handles max_depth items" do
    expect_load('x=[...]').to eq("x" => ["..."])
    expect_load('x={...}').to eq("x" => {"..." => ""})
  end

  it "handles unfinished lines" do
    expect_load('x=foo ').to eq("x" => "foo")
  end

  it "handles \\n at the end of line" do
    expect_load("x=foo\n").to eq("x" => "foo")
  end

  it "treats missing value in a pair as an empty string" do
    expect_load('x=').to eq("x" => "")
  end

  it "has non-greedy string parsing" do
    expect_load('x="#t" bar="baz"').to eq("x" => "#t", "bar" => "baz")
  end

  it "unscapes quotes in quoted strings" do
    expect_load("x='foo\\'bar'").to eq("x" => "foo'bar")
    expect_load('x="foo\"bar"').to eq("x" => 'foo"bar')
  end

  it "doesn't parse literals when they are keys" do
    expect_load("3=4").to eq("3" => 4)
  end

  it "handles some random stuff" do
    expect_load("=").to eq("" => "")
    expect_load('"\""=zzz').to eq('"' => "zzz")
  end

  it "knows how to restore iso time" do
    expect_load("at=2013-07-12T21:33:47Z").to eq("at" => Time.at(1373664827).utc)
  end

  it "can symbolize the names" do
    expect_load("foo=bar", symbolize_names: true).to eq(foo: "bar")
  end

  it "restores escaped characters from a string" do
    pending
    expect_load('\'\r\n\t\'=\'\r\n\t\'').to eq("\r\n\t" => "\r\n\t")
  end

  it "parses sample log lines" do
    expect_load("commit=716f337").to eq("commit" => "716f337")

    line = <<LINE
at=2013-07-12T21:33:47Z commit=716f337 sql="SELECT FROM_UNIXTIME(UNIX_TIMESTAMP(created_at) - UNIX_TIMESTAMP(created_at)%(300)) as timestamp FROM `job_queue_logs` WHERE `job_queue_logs`.`account_id` = 'effe376baf553c590c02090abe512278' AND (created_at >= '2013-06-28 16:56:12') GROUP BY timestamp" elapsed=[31.9 ms]
LINE
    expect_load(line).to eq(
      "at" => Time.at(1373664827).utc,
      "commit" => "716f337",
      "sql" => "SELECT FROM_UNIXTIME(UNIX_TIMESTAMP(created_at) - UNIX_TIMESTAMP(created_at)%(300)) as timestamp FROM `job_queue_logs` WHERE `job_queue_logs`.`account_id` = 'effe376baf553c590c02090abe512278' AND (created_at >= '2013-06-28 16:56:12') GROUP BY timestamp",
      "elapsed" => [31.9, "ms"],
    )
  end
end
