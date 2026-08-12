# Rakefile
require 'rspec/core/rake_task'

# Default `rake spec` runs the full suite (unit + integration).
RSpec::Core::RakeTask.new(:spec)

# `rake spec:unit` skips the network/integration specs (tagged :integration),
# mirroring what CI runs. Use XRPL_NETWORK=1 for the real Testnet locally.
namespace :spec do
  desc "Run unit specs only (excludes :integration)"
  RSpec::Core::RakeTask.new(:unit) do |t|
    t.rspec_opts = "--tag ~integration"
  end
end

desc "Run the full RSpec suite"
task default: :spec
