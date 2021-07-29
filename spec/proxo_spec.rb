# frozen_string_literal: true

RSpec.describe Proxo do
  it "has a version number" do
    expect(Proxo::VERSION).not_to be nil
  end

  it "does something useless" do
    expect(true).to eq(true)
  end
end
