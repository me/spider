source "http://rubygems.org"

# Default gems

gem "cmdparse", "> 2.0.0"
gem "fast_gettext", ">= 0.5.13"
gem "hpricot", "> 0.8"
gem "json_pure", "> 1.1"
gem "uuidtools", "> 2.1"
gem "rufus-scheduler", "> 1.0"
gem "mime-types", "> 1.0"
gem "locale", "> 2.0"
gem "builder", "> 2.1"
gem "macaddr", ">= 1.0.0"
gem "bundler"

# Optional gems

gem 'gettext', '>= 2.1.0', :group => :devel
gem 'fssm', :group => :devel
gem "json", :platforms => [:mri_18, :mri_19]
gem "mongrel"
gem "ripl", :platforms => [:ruby, :mingw]
gem "ripl-irb", :platforms => [:ruby, :mingw]
gem "ripl-multi_line", :platforms => [:ruby, :mingw]
gem "cldr", '>= 0.1.6'
gem "ruby-debug", :group => :devel, :platforms => [:mri_18]
gem "ruby-debug19", :group => :devel, :platforms => [:mri_19], :require => 'ruby-debug'
gem "ruby-prof", :group => :devel
gem "rspec", :group => :test
gem "cucumber", '~> 0.10.0', :group => :test
gem "capybara", :group => :test
gem "culerity", :group => :test
gem "yui-compressor", :group => :production

if RUBY_PLATFORM =~ /darwin/
  gem "rb-fsevent", :group => :devel, :platforms => [:mri]
end
if RUBY_PLATFORM =~ /linux/
  gem "rb-inotify", :group => :devel, :platforms => [:mri]
end

# Install specific gems


gem "mysql", :group => :mysql
gem "ruby-oci8", :group => :oci8
