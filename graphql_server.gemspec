
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "graphql_server/version"

Gem::Specification.new do |spec|
  spec.name          = "graphql_server"
  spec.version       = GraphQLServer::VERSION
  spec.authors       = ["Casey Kolderup"]
  spec.email         = ["casey.kolderup@voxmedia.com"]

  spec.summary       = %q{An opinionated library for writing GraphQL servers}
  spec.homepage      = "https://github.com/voxmedia/graphql_server"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "graphql", "~> 1.8"
  spec.add_dependency "graphql-batch", "~> 0.3.8"
  spec.add_dependency "graphql-errors", "~> 0.2.0"
  spec.add_dependency "activesupport", "~> 5.0"
  spec.add_dependency "activemodel", "~> 5.0"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.3.0"
end