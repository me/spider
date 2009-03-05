require 'spiderfw/model/storage/base_storage'

module Spider; module Model; module Storage

    class NullStorage

        def get_mapper(model)
            require 'spiderfw/model/mappers/null_mapper'
            mapper = Spider::Model::Mappers::NullMapper.new(model, self)
            return mapper
        end

        def parse_url(url)
        end

    end

end; end; end