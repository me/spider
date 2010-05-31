require 'rake'

Gem::Specification.new do |s|
  s.name     = "spiderfw"
  s.version  = File.read(File.dirname(__FILE__)+'/VERSION')
  s.date     = "2010-03-12"
  s.summary  = "A (web) framework"
  s.email    = "abmajor7@gmail.com"
  s.homepage = "http://github.com/me/spider"
  s.description = "Spider is yet another Ruby framework."
  s.has_rdoc = true
  s.authors  = ["Ivan Pirlik"]
  s.files = FileList[
      'README',
      'VERSION',
      'CHANGELOG',
      'Rakefile',
      'spider.gemspec',
      'apps/**/*',
      'bin/*',
      'blueprints/**/*',
      'data/**/*',
      'lib/**/*.rb',
      'views/**/*'
  ].to_a
#  s.test_files = []
#  s.rdoc_options = ["--main", "README.txt"]
#  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.executables = ['spider']
  s.default_executable = 'spider'
  s.add_dependency("cmdparse", ["> 2.0.0"])
  s.add_dependency("gettext", ["> 2.0.0"])
  s.add_dependency("hpricot", ["> 0.8"])
  s.add_dependency("json", ["> 1.1"])
  s.add_dependency("uuidtools", ["> 2.1"])
  s.add_dependency("rufus-scheduler", ["> 1.0"])
  s.add_dependency("mime-types", ["> 1.0"])
  s.add_dependency("locale", ["> 2.0"])
  s.add_dependency("builder", ["> 2.1"])
  s.add_dependency("macaddr", [">= 1.0.0"])
  s.add_development_dependency("rake", ["> 0.7.3"])
  s.add_development_dependency("ruby-debug", ["> 0.9.3"])
  s.requirements << "Optional dependencies: openssl, sqlite3, webrick, mongrel, ruby-oci8 >2.0, mysql"
  # optional dependencies
  # 
end
