require 'spec_helper'
require 'lines'
require 'stringio'

describe Lines do
  let(:outputter) { StringIO.new }
  let(:output) { outputter.string }
  before do
    Lines.use(outputter)
  end

  it "logs stuff" do
    Lines.log(foo: 'bar')
    expect(output).to eq('foo=bar' + Lines::NL)
  end

  it "supports a first msg argument" do
    Lines.log("this user is annoying", user: 'bob')
    expect(output).to eq('msg="this user is annoying" user=bob' + Lines::NL)
  end

  it "logs exceptions" do
    Lines.log(StandardError.new("error time!"), user: 'bob')
    expect(output).to eq('ex=StandardError msg="error time!" user=bob' + Lines::NL)
  end

  it "logs exception backtraces when available" do
    ex = (raise "foo" rescue $!)
    #expect(ex).not_to eq(nil)
    Lines.log(ex)
    expect(output).to match(/ex=RuntimeError msg=foo backtrace=\[[^\]]+\]/)
  end

  it "works with anything" do
    Lines.log("anything")
    expect(output).to eq('msg=anything' + Lines::NL)
  end

  it "has global context" do
    Lines.global["app"] = :self
    Lines.log({})
    Lines.global.replace({})
    expect(output).to eq('app=self' + Lines::NL)
  end

  it "has contextes" do
    Lines.context(foo: "bar").log(a: 'b')
    expect(output).to eq('a=b foo=bar' + Lines::NL)
  end

  it "has contextes with blocks" do
    Lines.context(foo: "bar") do |ctx|
      ctx.log(a: 'b')
    end
    expect(output).to eq('a=b foo=bar' + Lines::NL)
  end

  it "has a backward-compatible logger" do
    l = Lines.logger
    l.info("hi")
    expect(output).to eq('pri=info msg=hi' + Lines::NL)
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

  it "can dump a basicobject" do
    expect_dump(foo: BasicObject.new).to match(/foo=#<BasicObject:0x[0-9a-f]+>/)
  end

  it "can dump IO objects" do
    expect_dump(foo: File.open(__FILE__)).to match(/foo=#<File:[^>]+>/)
    expect_dump(foo: STDOUT).to eq("foo=#<IO:<STDOUT>>")
  end

  it "dumps time as ISO zulu format" do
    expect_dump(foo: Time.at(1337)).to eq('foo=1970-01-01T01:22:17+01:00')
  end

  it "dumps symbols as strings" do
    expect_dump(foo: :some_symbol).to eq('foo=some_symbol')
    expect_dump(foo: :"some symbol").to eq('foo="some symbol"')
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
    expect_dump(foo: [3, :ms]).to eq('foo=3ms')
    expect_dump(foo: [54.2, 's']).to eq('foo=54.2s')
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
