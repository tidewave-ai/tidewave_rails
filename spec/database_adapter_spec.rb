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
    context "when ActiveRecord is defined" do
      before do
        stub_const("ActiveRecord::Base", double("ActiveRecord::Base"))
      end

      it "returns an ActiveRecord adapter" do
        adapter = described_class.create_adapter
        expect(adapter).to be_a(Tidewave::DatabaseAdapters::ActiveRecord)
      end
    end

    context "when Sequel is defined but not ActiveRecord" do
      before do
        hide_const("ActiveRecord::Base") if defined?(ActiveRecord::Base)
        stub_const("Sequel::Model", double("Sequel::Model"))
      end

      it "returns a Sequel adapter" do
        adapter = described_class.create_adapter
        expect(adapter).to be_a(Tidewave::DatabaseAdapters::Sequel)
      end
    end
  end

  describe ".detect_orm" do
    context "when Rails configuration has a preferred ORM" do
      before do
        config = double("config", preferred_orm: :sequel)
        tidewave_config = double("tidewave_config", tidewave: config)
        application = double("application", config: tidewave_config)
        allow(Rails).to receive(:application).and_return(application)
        allow(Rails).to receive(:respond_to?).with(:application).and_return(true)
        allow(application).to receive(:respond_to?).with(:config).and_return(true)
        allow(tidewave_config).to receive(:respond_to?).with(:tidewave).and_return(true)

        stub_const("Sequel::Model", double("Sequel::Model"))
      end

      it "uses the preferred ORM when available" do
        orm = described_class.send(:detect_orm)
        expect(orm).to eq(:sequel)
      end
    end

    context "when auto-detecting" do
      before do
        allow(Rails).to receive(:respond_to?).with(:application).and_return(false)
      end

      it "detects ActiveRecord when defined" do
        stub_const("ActiveRecord::Base", double("ActiveRecord::Base"))
        orm = described_class.send(:detect_orm)
        expect(orm).to eq(:active_record)
      end

      it "detects Sequel when ActiveRecord is not defined" do
        hide_const("ActiveRecord::Base") if defined?(ActiveRecord::Base)
        stub_const("Sequel::Model", double("Sequel::Model"))
        orm = described_class.send(:detect_orm)
        expect(orm).to eq(:sequel)
      end
    end
  end

  describe ".orm_available?" do
    it "returns true when ActiveRecord is available" do
      stub_const("ActiveRecord::Base", double("ActiveRecord::Base"))
      expect(described_class.send(:orm_available?, :active_record)).to be(true)
    end

    it "returns true when Sequel is available" do
      stub_const("Sequel::Model", double("Sequel::Model"))
      expect(described_class.send(:orm_available?, :sequel)).to be(true)
    end

    it "returns false for unsupported ORMs" do
      expect(described_class.send(:orm_available?, :unknown)).to be(false)
    end
  end
end
