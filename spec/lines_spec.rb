require 'spec_helper'
require 'lines'
require 'stringio'

NL = "\n"

describe Lines do
  let(:outputter) { StringIO.new }
  let(:output) { outputter.string }
  before do
    Lines.configure(
      output: outputter,
      global: {}
    )
  end

  context ".log" do
    it "logs stuff" do
      Lines.log(foo: 'bar')
      expect(output).to eq('foo=bar' + NL)
    end

    it "supports a first msg argument" do
      Lines.log("this user is annoying", user: 'bob')
      expect(output).to eq("msg='this user is annoying' user=bob" + NL)
    end

    it "logs exceptions" do
      Lines.log(StandardError.new("error time!"), user: 'bob')
      expect(output).to eq("ex=StandardError msg='error time!' user=bob" + NL)
    end

    it "logs exception backtraces when available" do
      ex = (raise "foo" rescue $!)
      #expect(ex).not_to eq(nil)
      Lines.log(ex)
      expect(output).to match("ex=RuntimeError msg=foo ..." + NL)
    end

    it "works with anything" do
      Lines.log("anything1", "anything2")
      expect(output).to eq('msg=anything2' + NL)
    end

    it "doesn't convert nil args to msg" do
      Lines.log("anything", nil)
      expect(output).to eq('msg=anything' + NL)
    end
  end

  context ".context" do
    it "has contextes" do
      Lines.context(foo: "bar").log(a: 'b')
      expect(output).to eq('a=b foo=bar' + NL)
    end

    it "has contextes with blocks" do
      Lines.context(foo: "bar") do |ctx|
        ctx.log(a: 'b')
      end
      expect(output).to eq('a=b foo=bar' + NL)
    end

    it "mixes everything" do
      Lines.global[:app] = :self
      ctx = Lines.context(foo: "bar")
      ctx.log('msg', ahoi: true)
      expect(output).to eq('app=self msg=msg ahoi=#t foo=bar' + NL)
    end
  end

  context ".logger" do
    it "is provided for backward-compatibility" do
      l = Lines.logger
      l.info("hi")
      expect(output).to eq('pri=info msg=hi' + NL)
    end
  end

  context ".global" do
    it "prepends data to the line" do
      Lines.global["app"] = :self
      Lines.log 'hey'
      expect(output).to eq('app=self msg=hey' + NL)
    end

    it "resolves procs dynamically" do
      count = 0
      Lines.global[:count] = proc{ count += 1 }
      Lines.log 'test1'
      Lines.log 'test2'
      expect(output).to eq(
        'count=1 msg=test1' + NL +
        'count=2 msg=test2' + NL
      )
    end

    it "doesn't fail if a proc has an exception" do
      Lines.global[:X] = proc{ fail "error" }
      Lines.log 'test'
      expect(output).to eq("X='#<RuntimeError: error>' msg=test" + NL)
    end
  end
end

describe Lines::Dumper do
  subject { Lines::Dumper.new }
  def expect_dump(obj)
    expect(subject.dump obj)
  end

  it do
    expect_dump(foo: 'bar').to eq('foo=bar')
  end

  it "dumps true, false and nil as #t, #f and nil" do
    expect_dump(foo: true).to eq('foo=#t')
    expect_dump(foo: false).to eq('foo=#f')
    expect_dump(foo: nil).to eq('foo=nil')
  end

  it "dumps empty strings correclty" do
    expect_dump(foo: '').to eq('foo=')
  end

  it "dumps a string with spaces surrounded by single quotes" do
    expect_dump(foo: 'some" thing').to eq("foo='some\" thing'")
  end

  it "dumps a string with spaces and a single quote sourrounded with double quotes" do
    expect_dump(foo: "foo ' bar").to eq("foo=\"foo ' bar\"")
  end

  it "can dump a basicobject" do
    expect_dump(foo: BasicObject.new).to match(/foo='#<BasicObject:0x[0-9a-f]+>'/)
  end

  it "can dump IO objects" do
    expect_dump(foo: File.open(__FILE__)).to match(/foo='?#<File:[^>]+>'?/)
    expect_dump(foo: STDOUT).to match(/^foo='(?:#<IO:<STDOUT>>|#<IO:fd 1>)'$/)
  end

  it "dumps time as ISO zulu format" do
    expect_dump(foo: Time.at(1337)).to eq('foo=1970-01-01T00:22:17Z')
  end

  it "dumps date as ISO date" do
    expect_dump(foo: Date.new(1968, 3, 7)).to eq('foo=1968-03-07')
  end

  it "dumps symbols as strings" do
    expect_dump(foo: :some_symbol).to eq('foo=some_symbol')
    expect_dump(foo: :"some symbol").to eq("foo='some symbol'")
  end

  it "dumps numbers appropriately" do
    expect_dump(foo: 10e3).to eq('foo=10000.0')
    expect_dump(foo: 1).to eq('foo=1')
    expect_dump(foo: -1).to eq('foo=-1')
    # FIXME: don't put all the decimals
    #expect_dump(foo: 4.0/3).to eq('foo=1.333')
  end

  it "dumps arrays appropriately" do
    expect_dump(foo: [1,2,:a]).to eq('foo=[1 2 a]')
  end

  it "dumps [number, literal] tuples as numberliteral" do
    expect_dump(foo: [3, :ms]).to eq('foo=3:ms')
    expect_dump(foo: [54.2, 's']).to eq('foo=54.2:s')
  end

  it "knows how to handle circular dependencies" do
    x = {}
    x[:x] = x
    expect_dump(x).to eq('x={x={x={x={...}}}}')
  end
end

describe Lines::UniqueIDs do
  include Lines::UniqueIDs

  it "generates a unique ID" do
    expect(id.size).to be > 1
  end

  it "generates a unique ID on each call" do
    id1 = id
    id2 = id
    expect(id1).to_not eq(id2)
  end

end
