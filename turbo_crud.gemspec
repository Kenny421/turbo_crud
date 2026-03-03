# frozen_string_literal: true

# Gem specification: the gem's passport. 🛂
Gem::Specification.new do |spec|
  spec.name          = "turbo_crud"
  spec.version       = "0.4.8"
  spec.authors       = ["Kenny Reid"]
  spec.email         = ["your_email@example.com"] # update this

  spec.summary       = "Opinionated Turbo CRUD patterns for Rails."
  spec.description   = "TurboCrud adds controller responders, helpers, and generators to simplify CRUD with Turbo Frames and Streams. Supports modal and drawer forms, flash handling, and works with existing Rails apps or full scaffolds."
  
  spec.homepage      = "https://github.com/kenny421/turbo_crud"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  # 🔥 IMPORTANT: makes your gem look professional on RubyGems
  spec.metadata = {
    "source_code_uri" => "https://github.com/kenny421/turbo_crud",
    "changelog_uri" => "https://github.com/kenny421/turbo_crud/releases",
    "bug_tracker_uri" => "https://github.com/kenny421/turbo_crud/issues",
    "rubygems_mfa_required" => "true"
  }

  # Files included in the gem
  spec.files = Dir.chdir(__dir__) do
    Dir[
      "{app,lib,config,test}/**/*",
      "MIT-LICENSE",
      "README.md",
      "Rakefile"
    ]
  end

  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "rails", ">= 7.0", "< 9.0"
  spec.add_dependency "turbo-rails", ">= 1.0", "< 3.0"
end
