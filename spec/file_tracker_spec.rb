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

      expect(described_class.file_was_read?(test_path)).to be true
      expect(described_class.last_read_at(test_path)).to eq freeze_time
    end
  end

  describe '.file_was_read?' do
    let(:test_path) { 'test/path/file.rb' }
    let(:unread_path) { 'unread/path/file.rb' }

    before do
      described_class.record_read(test_path)
    end

    it 'returns true for a file that has been read' do
      expect(described_class.file_was_read?(test_path)).to be true
    end

    it 'returns false for a file that has not been read' do
      expect(described_class.file_was_read?(unread_path)).to be false
    end
  end

  describe '.file_exists?' do
    let(:existing_path) { 'test/path/file.rb' }
    let(:path_that_does_not_exist) { 'unread/path/file.rb' }

    it 'returns true for a file that exists' do
      expect(File).to receive(:exist?).with(described_class.file_full_path(existing_path)).and_return(true)

      expect(described_class.file_exists?(existing_path)).to be true
    end

    it 'returns false for a file that does not exist' do
      expect(File).to receive(:exist?).with(described_class.file_full_path(path_that_does_not_exist)).and_return(false)

      expect(described_class.file_exists?(path_that_does_not_exist)).to be false
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

  describe '.last_modified_at' do
    let(:test_path) { 'test/path/file.rb' }
    let(:full_path) { '/Users/sth/test/path/file.rb' }
    let(:frozen_time) { Time.now }

    before do
      allow(described_class).to receive(:file_full_path).with(test_path).and_return(full_path)
      allow(File).to receive(:mtime).with(full_path).and_return(frozen_time)
    end

    it 'returns the timestamp when a file was last modified' do
      expect(described_class.last_modified_at(test_path)).to eq(frozen_time)
    end
  end

  describe '.reset' do
    let(:test_path) { 'test/path/file.rb' }

    before do
      described_class.record_read(test_path)
    end

    it 'clears all tracked files' do
      expect(described_class.file_was_read?(test_path)).to be true

      described_class.reset

      expect(described_class.file_was_read?(test_path)).to be false
    end
  end

  describe '.project_files' do
    before do
      # Stub git root directory
      allow(described_class).to receive(:git_root).and_return("/path/to/repo")

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

  describe '.git_root' do
    before do
      # Reset the memoized git_root to force the command to be called
      described_class.instance_variable_set(:@git_root, nil)
    end

    it 'returns the git root directory' do
      allow(described_class).to receive(:`).with("git rev-parse --show-toplevel").and_return("/path/to/repo\n")
      expect(described_class.git_root).to eq("/path/to/repo")
    end

    it 'caches the git root directory' do
      # We need to ensure the stubbing happens before the first call
      allow(described_class).to receive(:`).with("git rev-parse --show-toplevel").once.and_return("/path/to/repo\n")

      # Call it twice
      result1 = described_class.git_root
      result2 = described_class.git_root

      # Both calls should return the same value
      expect(result1).to eq("/path/to/repo")
      expect(result2).to eq("/path/to/repo")

      # Should only execute the command once (verified by the .once constraint above)
    end
  end

  describe '.file_full_path' do
    it 'joins the git root with the given path' do
      allow(described_class).to receive(:git_root).and_return("/path/to/repo")
      expect(described_class.file_full_path("test/file.rb")).to eq("/path/to/repo/test/file.rb")
    end
  end

  describe '.validate_path_access!' do
    before do
      allow(described_class).to receive(:git_root).and_return("/path/to/repo")
      allow(File).to receive(:exist?).and_return(true)
    end

    it 'raises an error if path starts with ..' do
      expect {
        described_class.validate_path_access!("../outside/file.rb")
      }.to raise_error(ArgumentError, "File path must not start with '..'")
    end

    it 'raises an error if file is outside project directory' do
      allow(described_class).to receive(:file_full_path).with("hacked/path").and_return("/outside/path/to/repo")

      expect {
        described_class.validate_path_access!("hacked/path")
      }.to raise_error(ArgumentError, "File path must be within the project directory")
    end

    it 'raises an error if file does not exist' do
      allow(described_class).to receive(:file_full_path).with("missing/file.rb").and_return("/path/to/repo/missing/file.rb")
      allow(File).to receive(:exist?).with("/path/to/repo/missing/file.rb").and_return(false)

      expect {
        described_class.validate_path_access!("missing/file.rb")
      }.to raise_error(ArgumentError, "File not found: missing/file.rb")
    end

    it 'returns true if valid' do
      allow(described_class).to receive(:file_full_path).with("valid/file.rb").and_return("/path/to/repo/valid/file.rb")
      allow(File).to receive(:exist?).with("/path/to/repo/valid/file.rb").and_return(true)

      expect(described_class.validate_path_access!("valid/file.rb")).to be(true)
    end
  end

  describe '.validate_path_is_editable!' do
    let(:path) { "editable/file.rb" }

    before do
      allow(described_class).to receive(:validate_path_access!).with(path)
      allow(described_class).to receive(:validate_path_has_been_read_since_last_write!).with(path)
    end

    it 'calls validate_path_access!' do
      expect(described_class).to receive(:validate_path_access!).with(path)
      described_class.validate_path_is_editable!(path)
    end

    it 'calls validate_path_has_been_read_since_last_write!' do
      expect(described_class).to receive(:validate_path_has_been_read_since_last_write!).with(path)
      described_class.validate_path_is_editable!(path)
    end
  end

  describe '.validate_path_is_writable!' do
    let(:path) { "editable/file.rb" }

    before do
      allow(described_class).to receive(:validate_path_access!).with(path, validate_existence: false)
      allow(described_class).to receive(:validate_path_has_been_read_since_last_write!).with(path)
    end

    it 'calls validate_path_access!' do
      expect(described_class).to receive(:validate_path_access!).with(path, validate_existence: false)
      described_class.validate_path_is_writable!(path)
    end

    it 'calls validate_path_has_been_read_since_last_write!' do
      expect(described_class).to receive(:validate_path_has_been_read_since_last_write!).with(path)
      described_class.validate_path_is_writable!(path)
    end
  end

  describe '.validate_path_has_been_read_since_last_write!' do
    let(:path) { "editable/file.rb" }

    before do
      allow(described_class).to receive(:file_was_read_since_last_write?).with(path)
    end

    context 'when file_was_read_since_last_write? is true' do
      it 'returns true' do
        allow(described_class).to receive(:file_was_read_since_last_write?).with(path).and_return(true)
        expect(described_class.validate_path_has_been_read_since_last_write!(path)).to be true
      end
    end

    context 'when file_was_read_since_last_write? is false' do
      it 'raises ArgumentError' do
        allow(described_class).to receive(:file_was_read_since_last_write?).with(path).and_return(false)
        expect { described_class.validate_path_has_been_read_since_last_write!(path) }.to raise_error(ArgumentError, "File has been modified since last read, please read the file again")
      end
    end
  end

  describe '.file_was_read_since_last_write?' do
    let(:path) { "editable/file.rb" }

    before do
      allow(described_class).to receive(:file_was_read?).with(path).and_return(file_was_read)
      allow(described_class).to receive(:last_read_at).with(path)
      allow(described_class).to receive(:last_modified_at).with(path)
    end

    context 'when file_was_read? is true' do
      let(:file_was_read) { true }
      let(:frozen_time) { Time.now }

      context 'when last_read_at is superior to last_modified_at' do
        it 'returns true' do
          allow(described_class).to receive(:last_read_at).with(path).and_return(frozen_time + 1)
          allow(described_class).to receive(:last_modified_at).with(path).and_return(frozen_time)
          expect(described_class.file_was_read_since_last_write?(path)).to be true
        end
      end
      context 'when last_read_at is inferior to last_modified_at' do
        it 'returns false' do
          frozen_time = Time.now
          allow(described_class).to receive(:last_read_at).with(path).and_return(frozen_time - 1)
          allow(described_class).to receive(:last_modified_at).with(path).and_return(frozen_time)
          expect(described_class.file_was_read_since_last_write?(path)).to be false
        end
      end

      context 'when last_read_at is equal to last_modified_at' do
        it 'returns true' do
          allow(described_class).to receive(:last_read_at).with(path).and_return(frozen_time)
          allow(described_class).to receive(:last_modified_at).with(path).and_return(frozen_time)
          expect(described_class.file_was_read_since_last_write?(path)).to be true
        end
      end
    end

    context 'when file_was_read? is false' do
      let(:file_was_read) { false }
      it 'returns false' do
        allow(described_class).to receive(:file_was_read?).with(path).and_return(false)
        expect(described_class.file_was_read_since_last_write?(path)).to be false
      end
    end
  end

  describe '.read_file' do
    let(:test_path) { 'test/file.rb' }
    let(:full_path) { '/path/to/repo/test/file.rb' }
    let(:file_content) { 'file content' }

    before do
      allow(described_class).to receive(:validate_path_access!).with(test_path).and_return(test_path)
      allow(described_class).to receive(:file_full_path).with(test_path).and_return(full_path)
      allow(described_class).to receive(:record_read)
      allow(File).to receive(:read).with(full_path).and_return(file_content)
    end

    it 'validates the path access' do
      expect(described_class).to receive(:validate_path_access!).with(test_path)
      described_class.read_file(test_path)
    end

    it 'records the file as read' do
      expect(described_class).to receive(:record_read).with(test_path)
      described_class.read_file(test_path)
    end

    it 'reads and returns the file contents' do
      expect(described_class.read_file(test_path)).to eq(file_content)
    end
  end

  describe '.write_file' do
    let(:test_path) { 'test/file.rb' }
    let(:full_path) { '/path/to/repo/test/file.rb' }
    let(:file_content) { 'new file content' }
    let(:dirname) { '/path/to/repo/test' }

    before do
      allow(described_class).to receive(:file_full_path).with(test_path).and_return(full_path)
      allow(described_class).to receive(:record_read)
      allow(described_class).to receive(:validate_path_access!).with(test_path, validate_existence: false)
      allow(File).to receive(:dirname).with(full_path).and_return(dirname)
      allow(FileUtils).to receive(:mkdir_p).with(dirname)
      allow(File).to receive(:write)
      allow(described_class).to receive(:read_file).with(test_path)
    end

    it 'gets the full file path' do
      expect(described_class).to receive(:file_full_path).with(test_path)
      described_class.write_file(test_path, file_content)
    end

    it 'creates the directory' do
      expect(FileUtils).to receive(:mkdir_p).with(dirname)
      described_class.write_file(test_path, file_content)
    end

    it 'writes the content to the file' do
      expect(File).to receive(:write).with(full_path, file_content)
      described_class.write_file(test_path, file_content)
    end

    it 'reads the file' do
      expect(described_class).to receive(:read_file).with(test_path)
      described_class.write_file(test_path, file_content)
    end
  end
end
