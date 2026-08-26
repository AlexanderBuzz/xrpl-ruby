# frozen_string_literal: true

require 'rubygems'

# What ends up inside the built gem.
#
# A file that exists on disk but is missing from spec.files fails for nobody
# here: the suite loads the library from the working copy, where everything is
# present regardless of what the gemspec lists. It fails for whoever installs
# the gem. Since definitions.json is read at require time to build the
# transaction models, a missing data file is not a degraded feature but a
# library that will not load at all.
RSpec.describe 'the packaged gem' do
  ROOT = File.expand_path('..', __dir__)

  # The gemspec's globs are relative to the working directory.
  GEMSPEC = Dir.chdir(ROOT) { Gem::Specification.load('xrpl-ruby.gemspec') }

  FILES_ON_DISK = Dir.chdir(ROOT) do
    Dir.glob('lib/**/*').select do |path|
      File.file?(path) && !File.basename(path).start_with?('.')
    end
  end.freeze

  it 'is a loadable gemspec' do
    expect(GEMSPEC).to be_a(Gem::Specification)
    expect(GEMSPEC.name).to eq('xrpl-ruby')
  end

  it 'ships every file under lib/, whatever its extension' do
    missing = FILES_ON_DISK - GEMSPEC.files

    expect(missing).to be_empty
  end

  # Named on its own because losing this one file is the difference between a
  # missing feature and a gem that raises on require.
  it 'ships the definitions the transaction models are built from' do
    expect(GEMSPEC.files).to include('lib/binary-codec/enums/definitions.json')
  end

  it 'lists no file that is not there' do
    absent = Dir.chdir(ROOT) { GEMSPEC.files.reject { |path| File.file?(path) } }

    expect(absent).to be_empty
  end

  it 'leaves out what a consumer has no use for' do
    %w[spec/ examples/ coverage/ _scripts/].each do |prefix|
      expect(GEMSPEC.files.grep(/\A#{Regexp.escape(prefix)}/)).to be_empty
    end
  end

  it 'carries the version the library reports' do
    expect(GEMSPEC.version.to_s).to eq(XRPL::VERSION)
  end
end
