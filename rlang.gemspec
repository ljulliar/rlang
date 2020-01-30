lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rlang/version"

Gem::Specification.new do |spec|
  spec.name          = "rlang"
  spec.version       = Rlang::VERSION
  spec.authors       = ["Laurent Julliard"]
  spec.email         = ["laurent@moldus.org"]

  spec.summary       = %q{A (subset of) Ruby to WebAssembly compiler}
  spec.description   = %q{Rlang is meant to create fast and uncluttered WebAssembly code 
   from the comfort of the Ruby language. It is actually made of two things: a supported 
   subset of the Ruby language and a compiler transforming this Ruby subset in a valid 
   and fully runnable WebAssembly module.}
  spec.homepage      = "https://github.com/ljulliar/rlang"
  spec.license       = "MPL-2.0"

  #spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ljulliar/rlang"
  spec.metadata["changelog_uri"] = "https://github.com/ljulliar/rlang/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|featuresi|\.)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   << "rlang"
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "wasmer", "~> 5.0"
end
