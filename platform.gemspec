$:.push File.expand_path("../lib", __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "platform"
  s.version     = IO.read('VERSION')
  s.authors     = ["Michael Berkovich"]
  s.email       = ["theiceberk@gmail.com"]
  s.homepage    = "https://github.com/berk/platform"
  s.summary     = "Application Developer platform for extanding Rails applications by 3rd party developers."
  s.description = "This gem provides all necessary tools to make a Rails application into a platform with third party applications."

  s.rubyforge_project = 'platform'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,local,spec,features}/*`.split("\n")
  s.extra_rdoc_files = ['README.rdoc']
  s.require_paths = ['lib']

  s.licenses = ['MIT']

  s.add_dependency 'rails', ['~> 2.3.0']
  s.add_dependency 'will_filter', ['~> 2.3.0']
  s.add_dependency 'tr8n', ['~> 2.3.1']
  s.add_dependency 'aasm', ['>= 0']
end
