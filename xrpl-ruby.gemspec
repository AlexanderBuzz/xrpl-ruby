Gem::Specification.new do |spec|
  spec.name          = "xrpl-ruby"
  spec.version       = "0.0.3"
  spec.authors       = ["Alexander Busse"]
  spec.email         = ["dev@ledger-direct.com"]

  spec.summary       = "A Ruby library to interact with the XRP Ledger (XRPL) blockchain"
  spec.description   = "This gem provides a Ruby interface to interact with the XRP Ledger (XRPL) blockchain, allowing developers to easily integrate XRPL functionality into their Ruby applications."
  spec.homepage      = "https://github.com/AlexanderBuzz/xrpl-ruby"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*.rb"]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"

  # spec.add_runtime_dependency "some_dependency", "~> 1.0"
end