RUBY_VERSION_PARTS = RUBY_VERSION.split('.')
ENV['LC_CTYPE'] = 'en_US.UTF-8'

$SPIDER_PATH = File.expand_path(File.dirname(__FILE__)+'/../..')
$SPIDER_LIB = $SPIDER_PATH+'/lib'
$SPIDER_RUN_PATH ||= Dir.pwd
ENV['GETTEXT_PATH'] += ',' if (ENV['GETTEXT_PATH'])
ENV['GETTEXT_PATH'] ||= ''
ENV['GETTEXT_PATH'] += $SPIDER_PATH+'/data/locale,'+$SPIDER_RUN_PATH+'/data/locale'
#$:.push($SPIDER_LIB+'/spiderfw')
$:.push($SPIDER_RUN_PATH)

$:.push($SPIDER_PATH)
# Dir.chdir($SPIDER_RUN_PATH)

$SPIDER_RUNMODE ||= ENV['SPIDER_RUNMODE']
$SPIDER_CONFIG_SETS = ENV['SPIDER_CONFIG_SETS'].split(/\s+,\s+/) if ENV['SPIDER_CONFIG_SETS']

$SPIDER_SCRIPT = $0