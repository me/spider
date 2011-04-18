# def _(s)
#     s
# end

require 'fast_gettext'
include FastGettext::Translation
FastGettext.add_text_domain('spider', :path => File.join($SPIDER_PATH, 'data', 'locale'))
FastGettext.text_domain = 'spider'