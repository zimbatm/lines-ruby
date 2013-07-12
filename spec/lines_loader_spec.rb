require 'spec_helper'
require 'lines/loader'
require 'parslet/rig/rspec'

module Lines
  describe Loader do
    subject { Loader }

    def expect_load(str)
      expect(Loader.load str)
    end

    it "can load stuff" do
      expect_load('foo=bar bar=33').to eq("foo" => "bar", "bar" => 33)
    end

    it "handles max_depth items" do
      expect_load('x=[...]').to eq("x" => ["..."])
      expect_load('x={...}').to eq("x" => {"..." => ""})
    end

    it "treats missing value in a pair as an empty string" do
      expect_load('x=').to eq("x" => "")
    end

    it "has non-greedy string parsing" do
      expect_load('x="foo" bar="baz"').to eq("x" => "foo", "bar" => "baz")
    end

    it "unscapes quotes in quoted strings" do
      expect_load("x='foo\\'bar'").to eq("x" => "foo'bar")
      expect_load('x="foo\"bar"').to eq("x" => 'foo"bar')
    end

    it "parses sample log lines" do
      expect_load("commit=716f337").to eq("commit" => "716f337")


      line = <<LINE.strip
commit=716f337 sql="SELECT MAX(queued_jobs) as queued_jobs, MAX(processing_jobs) as processing_jobs, created_at, FROM_UNIXTIME(UNIX_TIMESTAMP(created_at) - UNIX_TIMESTAMP(created_at)%(300)) as timestamp FROM `job_queue_logs` WHERE `job_queue_logs`.`account_id` = 'effe376baf553c590c02090abe512278' AND (created_at >= '2013-06-28 16:56:12') GROUP BY timestamp" elapsed=31.9ms
LINE
      p line
      expect_load(line).to eq("x" => ["..."])
    end
  end

  describe Parser do
    let(:parser) { Parser.new }

    context "number parsing" do
      subject { parser.number }

      it "parses integers" do
        expect(subject).to     parse("0")
        expect(subject).to     parse("1")
        expect(subject).to     parse("-123")
        expect(subject).to     parse("120381")
        expect(subject).to     parse("181")
      end

      it "parses floats" do
        expect(subject).to     parse("0.1")
        expect(subject).to     parse("3.14159")
        expect(subject).to     parse("-0.00001")
        expect(subject).to_not parse("0.1.0")
        expect(subject).to_not parse("0..1")
      end
    end

    context "time parsing" do
      subject { parser.time }

      it "parses IS08601 zulu format" do
        expect(subject).to     parse("1979-05-27T07:32:00Z")
        expect(subject).to     parse("2013-02-24T17:26:21Z")
        expect(subject).to_not parse("2013-02-24T17:26:21+00:00")
      end
    end

    context "list parsing" do
      subject { parser.list }

      it "parses empty lists" do
        expect(subject).to     parse("[]")
      end

      it "parses max_depth lists" do
        expect(subject).to     parse("[...]")
      end

      it "parses normal lists" do
        expect(subject).to     parse("[a b 1 [2]]")
      end
    end

    context "pair parsing" do
      subject { parser.pair }

      it "parses k=v" do
        expect(subject).to     parse("commit=716f337")
      end
    end

    context "object parsing" do
      subject { parser.object }

      it "parses empty objects" do
        expect(subject).to     parse("{}")
      end

      it "parses max_depth objects" do
        expect(subject).to     parse("{...}")
      end

      it "parses normal objects" do
        expect(subject).to     parse("{foo=bar bar=baz}")
        expect(subject).to     parse("{'foo'=bar \"bar\"=baz}")
        expect(subject).to     parse("{commit=716f337}")
      end

      it "parses empty values" do
        expect(subject).to     parse("{foo=}")
      end
    end

    context "literal parsing" do
      subject { parser.literal }

      it "parses stuff" do
        expect(subject).to     parse("simple_string")
        expect(subject).to     parse("1")
        expect(subject).to     parse("33fgsdfgz333")
        expect(subject).to     parse("/\\-d()")
        expect(subject).to_not parse("dfsg dsfg")
        expect(subject).to_not parse("dfsg=dsfg")
      end
    end

    context "unit parsing" do
      subject { parser.unit }

      it "parses units" do
        expect(subject).to     parse("10:ms")
        expect(subject).to     parse("-0.2452:s")
      end
    end

    context "value parsing" do
      subject { parser.value }

      it "parses integers" do
        expect(subject).to     parse("1")
        expect(subject).to     parse("-123")
        expect(subject).to     parse("120381")
        expect(subject).to     parse("181")
      end

      it "parses floats" do
        expect(subject).to     parse("0.1")
        expect(subject).to     parse("3.14159")
        expect(subject).to     parse("-0.00001")
      end

      it "parses booleans" do
        expect(subject).to     parse("#t")
        expect(subject).to     parse("#f")
      end

      it "parses nil" do
        expect(subject).to     parse("nil")
      end

      it "parses datetimes" do
        expect(subject).to     parse("1979-05-27T07:32:00Z")
        expect(subject).to     parse("2013-02-24T17:26:21Z")
        expect(subject).to_not parse("1979l05-27 07:32:00")
      end

      it "parses strings" do
        expect(subject).to     parse('""')
        expect(subject).to     parse('"hello world"')
        expect(subject).to     parse('"hello\\nworld"')
        expect(subject).to     parse('"hello\\t\\n\\\\\\0world\\n"')
        expect(subject).to     parse("\"hello\nworld\"")
      end
    end
  end
end
