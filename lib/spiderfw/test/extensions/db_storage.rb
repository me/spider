require 'spiderfw/model/storage/db/db_storage'

module Spider; module Test

    class DbStorage < Spider::Model::Storage::Db::DbStorage

        def initialize
            super('stub')
        end

        def parse_url(url)
        end

    end

end; end