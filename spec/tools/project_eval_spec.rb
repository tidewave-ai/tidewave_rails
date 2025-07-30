# frozen_string_literal: true

describe Tidewave::Tools::ProjectEval do
  describe ".tool_name" do
    it "returns the correct tool name" do
      expect(described_class.tool_name).to eq("project_eval")
    end
  end

  describe ".description" do
    it "returns the correct description" do
      expect(described_class.description).to match(
        /Evaluates Ruby code in the context of the project/
      )
    end
  end

  describe "#call" do
    let(:code) { nil }

    context "without code writing to stdout" do
      let(:code) { "1 + 1" }

      it "returns the correct result" do
        result = described_class.new.call(code: code)

        expect(result).to eq("2")
      end
    end

    context 'with code writing to stdout' do
      let(:code) { "puts 'Hello, world!'" }

      it "returns the correct result" do
        result = described_class.new.call(code: code)

        expect(result).to eq(<<~OUTPUT)
          STDOUT:

          Hello, world!


          STDERR:



          Result:


        OUTPUT
      end
    end

    context 'with code writing to stderr' do
      let(:code) { "warn 'Hello, world!'" }

      it "returns the correct result" do
        result = described_class.new.call(code: code)

        expect(result).to eq(<<~OUTPUT)
          STDOUT:



          STDERR:

          Hello, world!


          Result:


        OUTPUT
      end
    end

    context 'with code writing to stdout, stderr and returning a value' do
      let(:code) { "puts 'Hello, world!'; warn 'How you doin?'; 1 + 1" }

      it "returns the correct result" do
        result = described_class.new.call(code: code)

        expect(result).to eq(<<~OUTPUT)
          STDOUT:

          Hello, world!


          STDERR:

          How you doin?


          Result:

          2
        OUTPUT
      end

      context 'with arguments parameter' do
        let(:code) { "arguments.sum" }

        it "returns the correct result" do
          result = described_class.new.call(code: code, arguments: [ 1, 2, 3 ])

          expect(result).to eq("6")
        end
      end

      context 'with timeout parameter' do
        let(:code) { "sleep(1); 42" }

        it "times out when evaluation takes too long" do
          result = described_class.new.call(code: code, timeout: 100)
          expect(result).to include("Timeout::Error: Evaluation timed out after 100 milliseconds")
        end
      end

      context 'with exception handling' do
        let(:code) { "raise StandardError, 'test error'" }

        it "returns formatted error" do
          result = described_class.new.call(code: code)

          expect(result).to include("test error (StandardError)")
        end
      end
    end

    describe "#call with json: true" do
      context "without code writing to stdout or stderr" do
        let(:code) { "1 + 1" }

        it "returns structured JSON result" do
          result = described_class.new.call(code: code, json: true)
          parsed = JSON.parse(result)

          expect(parsed).to eq({
            "result" => 2,
            "success" => true,
            "stdout" => "",
            "stderr" => ""
          })
        end
      end

      context 'with code writing to stdout' do
        let(:code) { "puts 'Hello, world!'; 42" }

        it "returns structured JSON result with stdout" do
          result = described_class.new.call(code: code, json: true)
          parsed = JSON.parse(result)

          expect(parsed["result"]).to eq(42)
          expect(parsed["success"]).to be(true)
          expect(parsed["stdout"]).to include("Hello, world!")
          expect(parsed["stderr"]).to eq("")
        end
      end

      context 'with code writing to stderr' do
        let(:code) { "warn 'Warning message'; 42" }

        it "returns structured JSON result with stderr" do
          result = described_class.new.call(code: code, json: true)
          parsed = JSON.parse(result)

          expect(parsed["result"]).to eq(42)
          expect(parsed["success"]).to be(true)
          expect(parsed["stdout"]).to eq("")
          expect(parsed["stderr"]).to include("Warning message")
        end
      end

      context 'with exception' do
        let(:code) { "raise StandardError, 'test error'" }

        it "returns structured JSON result with error" do
          result = described_class.new.call(code: code, json: true)
          parsed = JSON.parse(result)

          expect(parsed["success"]).to be(false)
          expect(parsed["result"]).to include("test error (StandardError)")
          expect(parsed["stdout"]).to eq("")
          expect(parsed["stderr"]).to eq("")
        end
      end

      context 'with arguments' do
        let(:code) { "arguments.map(&:upcase)" }

        it "returns structured JSON result with arguments" do
          result = described_class.new.call(code: code, arguments: [ "hello", "world" ], json: true)
          parsed = JSON.parse(result)

          expect(parsed).to eq({
            "result" => [ "HELLO", "WORLD" ],
            "success" => true,
            "stdout" => "",
            "stderr" => ""
          })
        end
      end

      context 'with timeout' do
        let(:code) { "sleep(1); 42" }

        it "captures timeout error" do
          result = described_class.new.call(code: code, timeout: 100, json: true)
          parsed = JSON.parse(result)

          expect(parsed["success"]).to be(false)
          expect(parsed["result"]).to include("Timeout::Error: Evaluation timed out after 100 milliseconds")
        end
      end

      context 'with stdout output and exception' do
        let(:code) { "puts 'Before error'; raise 'test error'" }

        it "captures stdout before exception" do
          result = described_class.new.call(code: code, json: true)
          parsed = JSON.parse(result)

          expect(parsed["success"]).to be(false)
          expect(parsed["stdout"]).to include("Before error")
          expect(parsed["result"]).to include("test error (RuntimeError)")
        end
      end
    end
  end
end
