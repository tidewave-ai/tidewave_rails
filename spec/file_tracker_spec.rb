# frozen_string_literal: true

describe Tidewave::FileTracker do
  # Clean up tracked files before each test
  before do
    described_class.reset
  end

  describe '.record_read' do
    let(:test_path) { 'test/path/file.rb' }

    it 'records the timestamp when a file is read' do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)

      described_class.record_read(test_path)

      expect(described_class.file_read?(test_path)).to be true
      expect(described_class.last_read_at(test_path)).to eq freeze_time
    end
  end

  describe '.file_read?' do
    let(:test_path) { 'test/path/file.rb' }
    let(:unread_path) { 'unread/path/file.rb' }

    before do
      described_class.record_read(test_path)
    end

    it 'returns true for a file that has been read' do
      expect(described_class.file_read?(test_path)).to be true
    end

    it 'returns false for a file that has not been read' do
      expect(described_class.file_read?(unread_path)).to be false
    end
  end

  describe '.last_read_at' do
    let(:test_path) { 'test/path/file.rb' }
    let(:unread_path) { 'unread/path/file.rb' }

    before do
      freeze_time = Time.now
      allow(Time).to receive(:now).and_return(freeze_time)
      described_class.record_read(test_path)
    end

    it 'returns the timestamp when a file was last read' do
      expect(described_class.last_read_at(test_path)).to eq Time.now
    end

    it 'returns nil for a file that has not been read' do
      expect(described_class.last_read_at(unread_path)).to be_nil
    end
  end

  describe '.reset' do
    let(:test_path) { 'test/path/file.rb' }

    before do
      described_class.record_read(test_path)
    end

    it 'clears all tracked files' do
      expect(described_class.file_read?(test_path)).to be true

      described_class.reset

      expect(described_class.file_read?(test_path)).to be false
    end
  end

  describe '.project_files' do
    before do
      # Stub the git repository check
      allow(described_class).to receive(:system).with("git rev-parse --is-inside-work-tree > /dev/null 2>&1").and_return(true)

      # Stub git root directory
      allow(described_class).to receive(:`).with("git rev-parse --show-toplevel").and_return("/path/to/repo\n")

      # Stub Dir.chdir to execute the block directly without changing directory
      allow(Dir).to receive(:chdir).and_yield

      # Stub git ls-files for tracked files
      tracked_files = "file1.rb\nfile2.rb\n"
      allow(described_class).to receive(:`).with("git ls-files").and_return(tracked_files)

      # Stub git ls-files for untracked files
      untracked_files = "file3.rb\n"
      allow(described_class).to receive(:`).with("git ls-files --others --exclude-standard").and_return(untracked_files)
    end

    it "returns both tracked and untracked files" do
      expected_files = [ "file1.rb", "file2.rb", "file3.rb" ]
      expect(described_class.project_files).to match_array(expected_files)
    end
  end
end
