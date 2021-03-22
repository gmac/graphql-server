require_relative 'lib/graphql_server/version'

Gem::Specification.new do |spec|
  spec.name          = "graphql_server"
  spec.version       = GraphQLServer::VERSION
  spec.authors       = ["Casey Kolderup", "Greg MacWilliam"]

  spec.summary       = %q{An opinionated library for writing GraphQL servers}
  spec.description   = %q{An opinionated way to build GraphQL in Ruby via SDL with resolvers}
  spec.homepage      = "https://github.com/gmac/graphql-server-fork"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "graphql", "~> 1.12"
  spec.add_dependency "graphql-batch", "~> 0.4.3"
  spec.add_dependency "graphql-errors", "~> 0.2.0"
  spec.add_dependency "activesupport", ">= 5.0"
  spec.add_dependency "activemodel", ">= 5.0"

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.4"
  spec.add_development_dependency "warning", "~> 1.1"
end
