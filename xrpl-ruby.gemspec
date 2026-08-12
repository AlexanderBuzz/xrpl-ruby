require_relative "lib/xrpl/version"

Gem::Specification.new do |spec|
  spec.name          = "xrpl-ruby"
  spec.version       = XRPL::VERSION
  spec.authors       = ["Alexander Busse"]
  spec.email         = ["dev@ledger-direct.com"]

  spec.summary       = "A Ruby library to interact with the XRP Ledger (XRPL) blockchain"
  spec.description   = "This gem provides a Ruby interface to interact with the XRP Ledger (XRPL) blockchain, allowing developers to easily integrate XRPL functionality into their Ruby applications."
  spec.homepage      = "https://github.com/AlexanderBuzz/xrpl-ruby"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri"    => "https://github.com/AlexanderBuzz/xrpl-ruby",
    "source_code_uri" => "https://github.com/AlexanderBuzz/xrpl-ruby",
    "changelog_uri"   => "https://github.com/AlexanderBuzz/xrpl-ruby/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/AlexanderBuzz/xrpl-ruby/issues"
  }

  spec.files         = Dir["lib/**/*.rb"] +
                       Dir["lib/binary-codec/enums/definitions.json"] +
                       ["README.md", "CHANGELOG.md", "LICENSE"]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  spec.add_runtime_dependency "bigdecimal", "~> 3.1"
  spec.add_runtime_dependency "ed25519", "~> 1.3"
  spec.add_runtime_dependency "ecdsa", "~> 1.2.0"
  spec.add_runtime_dependency "faye-websocket", "~> 0.11"
  spec.add_runtime_dependency "eventmachine", "~> 1.2"
end
