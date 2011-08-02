require 'date'

Gem::Specification.new do |s|
  s.name     = "spiderfw"
  s.version  = File.read(File.dirname(__FILE__)+'/VERSION')
  s.date     = File.mtime("VERSION").strftime("%Y-%m-%d")
  s.summary  = "A (web) framework"
  s.email    = "abmajor7@gmail.com"
  s.homepage = "http://github.com/me/spider"
  s.description = "Spider is yet another Ruby framework."
  s.has_rdoc = true
  s.authors  = ["Ivan Pirlik"]
  s.files = [
      'README.rdoc',
      'VERSION',
      'CHANGELOG',
      'Rakefile',
      'spider.gemspec'] \
      + Dir.glob('apps/**/*') \
      + Dir.glob('bin/*') \
      + Dir.glob('blueprints/**/*', File::FNM_DOTMATCH) \
      + Dir.glob('data/**/*') \
      + Dir.glob('lib/**/*.rb') \
      + Dir.glob('views/**/*')
#  s.test_files = []
#  s.rdoc_options = ["--main", "README.rdoc"]
#  s.extra_rdoc_files = ["CHANGELOG", "LICENSE", "README.rdoc"]
  s.executables = ['spider']
  s.default_executable = 'spider'
  s.add_dependency("cmdparse", ["> 2.0.0"])
  s.add_dependency("fast_gettext", [">= 0.5.13"])
  s.add_dependency("hpricot", ["> 0.8"])
  s.add_dependency("json_pure", ["> 1.1"])
  s.add_dependency("uuidtools", ["> 2.1"])
  s.add_dependency("rufus-scheduler", ["> 1.0"])
  s.add_dependency("mime-types", ["> 1.0"])
  s.add_dependency("locale", ["> 2.0"])
  s.add_dependency("builder", ["> 2.1"])
  s.add_dependency("macaddr", [">= 1.0.0"])
  s.add_dependency("bundler")
  s.add_development_dependency("rake", ["> 0.7.3"])
  s.add_development_dependency("ruby-debug", ["> 0.9.3"])
  s.requirements << "Optional dependencies: ripl, ripl-irb, ripl-multi_line, json, openssl, sqlite3, webrick, mongrel, ruby-oci8 >2.0, mysql, yui-compressor, home_run, cldr"
  # optional dependencies
  # 
end
