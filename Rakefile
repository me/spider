require 'spiderfw'
desc "Update pot/po files."
task :updatepo do
  require 'gettext/utils'
  GetText.update_pofiles("spider", Dir.glob("{lib,bin}/**/*.{rb,rhtml}"), "Spider #{Spider.version}")
end

desc "Create mo-files"
task :makemo do
  require 'gettext/utils'
  GetText.create_mofiles(true)
  # GetText.create_mofiles(true, "po", "locale")  # This is for "Ruby on Rails".
end