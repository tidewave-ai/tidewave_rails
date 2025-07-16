# frozen_string_literal: true

require "rails_helper"

describe Tidewave::DatabaseAdapter do
  describe ".current" do
    it "returns the same adapter instance on subsequent calls" do
      adapter1 = described_class.current
      adapter2 = described_class.current
      expect(adapter1).to be(adapter2)
    end
  end

  describe ".create_adapter" do
    context "when preferred_orm is :active_record" do
      before do
        config = double("config", preferred_orm: :active_record)
        tidewave_config = double("tidewave_config", tidewave: config)
        application = double("application", config: tidewave_config)
        allow(Rails).to receive(:application).and_return(application)
      end

      it "returns an ActiveRecord adapter" do
        adapter = described_class.create_adapter
        expect(adapter).to be_a(Tidewave::DatabaseAdapters::ActiveRecord)
      end
    end

    context "when preferred_orm is :sequel" do
      before do
        config = double("config", preferred_orm: :sequel)
        tidewave_config = double("tidewave_config", tidewave: config)
        application = double("application", config: tidewave_config)
        allow(Rails).to receive(:application).and_return(application)
      end

      it "returns a Sequel adapter" do
        adapter = described_class.create_adapter
        expect(adapter).to be_a(Tidewave::DatabaseAdapters::Sequel)
      end
    end

    context "when preferred_orm is unknown" do
      before do
        config = double("config", preferred_orm: :unknown)
        tidewave_config = double("tidewave_config", tidewave: config)
        application = double("application", config: tidewave_config)
        allow(Rails).to receive(:application).and_return(application)
      end

      it "raises an error" do
        expect { described_class.create_adapter }.to raise_error("Unknown preferred ORM: unknown")
      end
    end
  end
end
