# frozen_string_literal: true

RSpec.describe Tidewave do
  it "has a version number" do
    expect(Tidewave::VERSION).not_to be nil
  end

  it "injects Rails configuration" do
    config = Rails.configuration.tidewave
    expect(config).to be_a(Tidewave::Configuration)
    expect(config.logger.instance_variable_get(:@logdev).filename).to eq(Rails.root.join("log/tidewave.log"))
  end
end
