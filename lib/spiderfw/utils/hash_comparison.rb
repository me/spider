module HashComparison
    def eql?(h)
        self == h
    end
    def hash
        self.to_a.hash
    end
end