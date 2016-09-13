require './lib/net/version'

Gem::Specification.new do |spec|
  spec.name          = "net-server"
  spec.version       = Net::BUILD_VERSION
  spec.date          = Net::BUILD_DATE
  spec.authors       = ["Michael J. Welch, Ph.D."]
  spec.email         = ["mjwelchphd@gmail.com"]
  spec.author        = 'Michael J. Welch, Ph.D.'
  spec.description   = %q{Ruby Net server.}
  spec.summary       = %q{Ruby Net server.}
  spec.homepage      = "https://github.com/mjwelchphd/net-server"
  spec.license       = "MIT"
  spec.files         = Dir['lib/net/*'] + Dir['*.md']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
end
