# frozen_string_literal: true

# rubocop:disable Layout/LeadingCommentSpace

require "active_support/core_ext/object/blank"

describe Tidewave::Tools::GetDocs do
  describe "#call" do
    subject { described_class.new.call(reference: reference) }

    # Test method with documentation
    let(:documented_method_line) { __LINE__ + 4 }
    test_module = Class.new do
      # This is a documented method
      # It does something important
      def self.documented_method
        'documented'
      end

      # This method has documentation
      # with multiple lines
      # and preserves indentation
      def documented_instance_method
        'instance'
      end

      def undocumented_method
        'undocumented'
      end

      #This comment has no space after hash
      def no_space_comment_method
        'no_space'
      end

      # This method has docs

      # with empty lines in between

      def docs_with_empty_lines
        'empty_lines'
      end

      #This is a comment without space
      #Another comment
      def multiple_no_space_comments
        'multiple_no_space'
      end

      # Comment with space
      #Comment without space
      def mixed_comment_styles
        'mixed'
      end
    end

    let(:module_line_number) { __LINE__ + 1 }
    Object.const_set(:TidewaveDocsTestModule, test_module)

    context "when the method has documentation" do
      let(:reference) { 'TidewaveDocsTestModule.documented_method' }

      it "returns the documentation" do
        expect(subject).to eq("This is a documented method\nIt does something important")
      end
    end

    context "when the instance method has documentation" do
      let(:reference) { 'TidewaveDocsTestModule#documented_instance_method' }

      it "returns the documentation" do
        expect(subject).to eq("This method has documentation\nwith multiple lines\nand preserves indentation")
      end
    end

    context "when the method has no documentation" do
      let(:reference) { 'TidewaveDocsTestModule#undocumented_method' }

      it "returns nil for documentation" do
        expect(subject).to be_nil
      end
    end

    context "when the comment has no space after hash" do
      let(:reference) { 'TidewaveDocsTestModule#no_space_comment_method' }

      it "returns the documentation without the hash" do
        expect(subject).to eq("This comment has no space after hash")
      end
    end

    context "when the method has documentation with empty lines" do
      let(:reference) { 'TidewaveDocsTestModule#docs_with_empty_lines' }

      it "returns the documentation ignoring empty lines between" do
        expect(subject).to eq("This method has docs\nwith empty lines in between")
      end
    end

    context "when the module is found" do
      let(:reference) { 'TidewaveDocsTestModule' }

      it "returns nil for no documentation" do
        expect(subject).to be_nil
      end
    end

    context "when the reference is not found" do
      let(:reference) { "NonExistentModule" }

      it "raises an error" do
        expect { subject }.to raise_error(NameError, "could not find docs for NonExistentModule")
      end
    end

    context "when the reference is invalid" do
      let(:reference) { "1+2" }

      it "raises an error" do
        expect { subject }.to raise_error(NameError, "wrong constant name 1+2")
      end
    end

    context "when the method has multiple comments without space after hash" do
      let(:reference) { 'TidewaveDocsTestModule#multiple_no_space_comments' }

      it "extracts the documentation without the hash" do
        expect(subject).to eq("This is a comment without space\nAnother comment")
      end
    end

    context "when the method has mixed comment styles" do
      let(:reference) { 'TidewaveDocsTestModule#mixed_comment_styles' }

      it "extracts both types of comments" do
        expect(subject).to eq("Comment with space\nComment without space")
      end
    end

    context "when getting docs for Rails/ActiveSupport methods" do
      let(:reference) { 'String#presence' }

      it "returns documentation for ActiveSupport extensions" do
        expect(subject).to match("presence")
      end
    end
  end
end
