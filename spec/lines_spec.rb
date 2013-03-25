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

  it "works with anything" do
    Lines.log("anything")
    expect(output).to eq('msg=anything' + Lines::NL)
  end
end

describe Lines::Dumper do
  subject { Lines::Dumper.new }

  it do
    expect(subject.dump foo: 'bar').to eq('foo=bar')
  end

  it "dumps empty strings correclty" do
    expect(subject.dump foo: '').to eq('foo=')
  end

  it "can dump a basicobject" do
    expect(subject.dump foo: BasicObject.new).to match(/foo=#<BasicObject:0x[0-9a-f]+>/)
  end

  it "can dump IO objects" do
    expect(subject.dump foo: File.open(__FILE__)).to match(/foo=#<File:[^>]+>/)
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
