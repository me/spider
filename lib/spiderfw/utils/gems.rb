module Spider
   
    # TODO: remove when old RubyGems versions are not a problem anymore
    def self.gem_available?(name, *requirements)
        if Gem::Specification.respond_to?(:find_by_name)
            Gem::Specification.find_by_name(name, *requirements)
        else
            Gem.available?(name, requirements.first)
        end
    end 

end