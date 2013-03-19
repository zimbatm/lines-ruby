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
    expect(output).to eq('foo=bar')
  end
end

describe Lines::Dumper do
  include Lines::Dumper

  it "works" do
    expect(dump foo: 'bar').to eq('foo=bar')
  end

  it "dumps empty strings correclty" do
    expect(dump foo: '').to eq('foo=""')
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
