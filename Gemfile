source "http://rubygems.org"

gemspec :development_group => :devel

# Optional gems

gem "json", :platforms => [:mri_18, :mri_19]
gem "mongrel", '>= 1.2.0.pre2'
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

# gem "mysql", :group => :mysql
# gem "ruby-oci8", :group => :oci8
