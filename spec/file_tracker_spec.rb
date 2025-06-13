# frozen_string_literal: true

describe Tidewave::FileTracker do
  let(:git_root) { "/path/to/repo" }

  describe '.project_files' do
    before do
      allow(described_class).to receive(:git_root).and_return(git_root)
    end

    it "returns project files" do
      allow(described_class).to receive(:`).with("git --git-dir #{git_root}/.git ls-files --cached --others --exclude-standard").and_return("file1.rb\nfile2.rb\n")
      expect(described_class.project_files).to match_array([ "file1.rb", "file2.rb" ])
    end

    it "accepts options" do
      allow(described_class).to receive(:`).with("git --git-dir #{git_root}/.git ls-files --cached --others *.rb").and_return("file1.rb\nfile2.rb\n")
      expect(described_class.project_files(glob_pattern: "*.rb", include_ignored: true).to match_array([ "file1.rb", "file2.rb" ])
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
        described_class.validate_path_access!("inside/../../file.rb")
      }.to raise_error(ArgumentError, "File path must not contain '..'")
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

  describe '.validate_path_access!' do
    let(:test_path) { 'test/file.rb' }
    let(:full_path) { '/path/to/repo/test/file.rb' }

    before do
      allow(described_class).to receive(:git_root).and_return(git_root)
    end

    it 'succeeds at validating the path exists' do
      expect(File).to receive(:exist?).with(full_path).and_return(true)
      expect(described_class.validate_path_access!(test_path)).to eq(true)
    end

    it 'raises if file does not exist' do
      expect(File).to receive(:exist?).with(full_path).and_return(false)
      expect { described_class.validate_path_access!(test_path) }.to raise_error(ArgumentError, "File not found: test/file.rb")
    end
  end

  describe '.validate_path_is_editable!' do
    let(:test_path) { 'test/file.rb' }
    let(:full_path) { '/path/to/repo/test/file.rb' }

    before do
      allow(described_class).to receive(:git_root).and_return(git_root)
      allow(File).to receive(:exist?).with(full_path).and_return(true)
    end

    it 'succeeds if not atime is given' do
      expect(described_class.validate_path_is_editable!(test_path, nil)).to eq(true)
    end

    it 'succeeds if atime is given and it has not changed more recently' do
      allow(File).to receive(:mtime).with(full_path).and_return(Time.new(0))
      expect(described_class.validate_path_is_editable!(test_path, 0)).to eq(true)
    end

    it 'raises if file exists and it has changed more recently' do
      allow(File).to receive(:mtime).with(full_path).and_return(Time.new(2000))
      expect { described_class.validate_path_is_editable!(test_path, 0) }.to raise_error(ArgumentError, "File has been modified since last read, please read the file again")
    end
  end

  describe '.validate_path_is_writable!' do
    let(:test_path) { 'test/file.rb' }
    let(:full_path) { '/path/to/repo/test/file.rb' }

    before do
      allow(described_class).to receive(:git_root).and_return(git_root)
      allow(File).to receive(:exist?).with(full_path).and_return(false)
    end

    it 'succeeds if not atime is given' do
      expect(described_class.validate_path_is_writable!(test_path, nil)).to eq(true)
    end

    it 'succeeds if atime is given and it has not changed more recently' do
      allow(File).to receive(:mtime).with(full_path).and_return(Time.new(0))
      expect(described_class.validate_path_is_writable!(test_path, 0)).to eq(true)
    end

    it 'raises if file exists and it has changed more recently' do
      allow(File).to receive(:mtime).with(full_path).and_return(Time.new(2000))
      expect { described_class.validate_path_is_writable!(test_path, 0) }.to raise_error(ArgumentError, "File has been modified since last read, please read the file again")
    end
  end

  describe '.read_file' do
    let(:test_path) { 'test/file.rb' }
    let(:full_path) { '/path/to/repo/test/file.rb' }
    let(:file_content) { "line1\nline2\nline3\nline4\nline5\n" }
    let(:mtime) { Time.new(1971) }

    before do
      allow(described_class).to receive(:git_root).and_return(git_root)
      allow(File).to receive(:read).with(full_path).and_return(file_content)
      allow(File).to receive(:mtime).with(full_path).and_return(mtime)
    end

    it 'reads and returns the full file contents when no offset or count given' do
      expect(described_class.read_file(test_path)).to eq([ mtime.to_i, file_content ])
    end

    it 'reads file contents with line_offset' do
      expect(described_class.read_file(test_path, line_offset: 2))
        .to eq([ mtime.to_i, "line3\nline4\nline5\n" ])
    end

    it 'reads file contents with count' do
      expect(described_class.read_file(test_path, count: 2))
        .to eq([ mtime.to_i, "line1\nline2\n" ])
    end

    it 'reads file contents with both line_offset and count' do
      expect(described_class.read_file(test_path, line_offset: 1, count: 2))
        .to eq([ mtime.to_i, "line2\nline3\n" ])
    end

    it 'handles line_offset beyond file length' do
      expect(described_class.read_file(test_path, line_offset: 10))
        .to eq([ mtime.to_i, "" ])
    end
  end

  describe '.write_file' do
    let(:test_path) { 'test/file.rb' }
    let(:full_path) { '/path/to/repo/test/file.rb' }
    let(:file_content) { 'new file content' }
    let(:dirname) { '/path/to/repo/test' }

    before do
      allow(described_class).to receive(:git_root).and_return(git_root)
      allow(FileUtils).to receive(:mkdir_p).with(dirname)
      allow(File).to receive(:write)
    end

    it 'gets the full file path' do
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

    context 'with Ruby files' do
      let(:test_path) { 'test/file.rb' }

      it 'validates valid Ruby syntax' do
        valid_ruby = "def test\n  puts 'hello'\nend"
        expect { described_class.write_file(test_path, valid_ruby) }.not_to raise_error
      end

      it 'raises error on invalid Ruby syntax' do
        invalid_ruby = "def test\n  puts 'hello'\n" # Missing end
        expect {
          described_class.write_file(test_path, invalid_ruby)
        }.to raise_error(RuntimeError, /Invalid Ruby syntax: .+ unexpected end-of-input/m)
      end

      it 'does not write file if syntax is invalid' do
        invalid_ruby = "def test\n  puts 'hello'\n" # Missing end
        expect(File).not_to receive(:write)
        begin
          described_class.write_file(test_path, invalid_ruby)
        rescue RuntimeError
          # Expected error
        end
      end
    end

    context 'with non-Ruby files' do
      let(:test_path) { 'test/file.txt' }

      it 'skips syntax validation' do
        invalid_ruby = "def test\n  puts 'hello'\n" # Invalid Ruby but valid text
        expect { described_class.write_file(test_path, invalid_ruby) }.not_to raise_error
      end
    end
  end
end
