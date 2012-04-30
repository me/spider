source "http://rubygems.org"

gemspec :development_group => :devel

# Optional gems

gem "json", :platforms => [:mri_18, :mri_19]
gem "mongrel", '>= 1.2.0.pre2'
gem "cldr", '>= 0.1.6'
gem "pry"
gem "pry-nav"
gem "ruby-debug", :group => :devel, :platforms => [:ruby_18, :mingw_18, :jruby]
gem "ruby-debug-pry", :require => "ruby-debug/pry", :group => :devel, :platforms => [:ruby_18, :mingw_18]
gem "pry-stack_explorer", :group => :devel, :platforms => [:ruby_19, :mri_19]
gem "pry-exception_explorer", :group => :devel, :platforms => [:ruby_19, :mri_19]
gem "ruby-prof", :group => :devel
gem "sass", :group => :devel
gem "compass", :group => :devel
gem "rspec", :group => :test
gem "cucumber", '~> 0.10.0', :group => :test
gem "capybara", :group => :test
gem "culerity", :group => :test
gem "yui-compressor", :group => :production
gem "git", :group => :devel

if RUBY_PLATFORM =~ /darwin/
  gem "rb-fsevent", :group => :devel, :platforms => [:mri]
end
if RUBY_PLATFORM =~ /linux/
  gem "rb-inotify", :group => :devel, :platforms => [:mri]
end

# Install specific gems

# gem "mysql", :group => :mysql
# gem "ruby-oci8", :group => :oci8
