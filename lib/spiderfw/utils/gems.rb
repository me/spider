module Spider
   
    # TODO: remove when old RubyGems versions are not a problem anymore
    def self.gem_available?(name, *requirements)
        if Gem::Specification.respond_to?(:find_by_name)
            begin
                Gem::Specification.find_by_name(name, *requirements)
            rescue Gem::LoadError
                return false
            end
        else
            Gem.available?(name, requirements.first)
        end
    end 

end