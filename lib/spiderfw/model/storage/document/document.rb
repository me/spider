module Spider; module Model; module Storage
    module Document
    end
    
    Document.autoload(:Mongodb, 'spiderfw/model/storage/document/adapters/mongodb')
    
end; end; end