require 'rubygems'
require 'uuidtools'
require 'spiderfw/utils/shared_store'

module Locking
	module ClassMethods; end
	
	def Locking.included(other)
		other.extend(ClassMethods)
	end
	
	class Lock
		attr_reader :resource, :properties, :token, :created
		
		def initialize(resource, properties)
			@resource = resource
			@properties = properties
			@created = Time.now
			
			@token = UUIDTools::UUID.random_create.to_s
		end
		
		def [](key)
			@properties[key]
		end
		
		def method_missing(meth, *args)
			@properties.include?(meth.to_sym) ? @properties[meth.to_sym] : nil
		end
		
		# Overload type, because ruby already defines it
		def type
			@properties[:type]
		end
		
		# Overload private timeout, who defines it, we don't know
		def timeout
			@properties[:timeout]
		end
		
		def timeout=(val)
		    @properties[:timeout] = val
	    end
	end
	
	module ClassMethods
	    
	    def lockstore
			@lockstore ||= Spider::Utils::SharedStore.get(nil, :name => 'dav_locks')
		end
	    
		def locking?
			true
		end
		
	end
	
	def locking?
	    true
    end

    def lockstore
        self.class.lockstore
    end
		
		
	def timeout=(timeout)
		@timeout = timeout
	end
	
	def locked?(resource, uid = nil)
		resource = "/#{resource}" unless resource[0] == ?/
		
		# Check if resource is directly locked
		return lockstore[resource] if lockstore.include?(resource)
		
		item = resource
		depth = 0
		
		# Check if resource is indirectly locked
		while true
			item = File.split(item).first
			
			if lockstore.include?(item)
				locks = check_timeout(item)
				
				locks.each do |lock|
					return lock if (lock.depth == 'infinite' or lock.depth == depth)
				end
			end

			break if item == '/'
			depth += 1
		end
		
		return nil
	end
	
	def check_timeout(resource)
		lockstore[resource].delete_if do |lock|
		    if (lock.timeout && lock.timeout)
		        if (lock.timeout =~ /Second-(\d+)/)
		            t = Time.now
		            t += $1.to_i
		            return true if (Time.now - lock.created) < $1.to_i
	            end
            end
            return false
		end
		
		if lockstore[resource].empty?
			lockstore.delete(resource)
			[]
		else
			lockstore[resource]
		end
	end
	
	def child_locked?(resource, exclusive)
		# This method checks if some child in resource is locked
		lockstore.each_key do |key|
			next unless key.index(resource) == 0

			return true if exclusive
			
			
			lockstore[key].each do |lock|
				return true if lock.scope == 'exclusive'
			end
		end
		
		false
	end
	
	def lock(resource, properties)
		# Check for direct locks of #resource
		locks = locked?(resource)
		
		if locks
			locks.each do |lock|
				return nil if (lock.scope == 'exclusive' || properties[:scope] == 'exclusive')
			end
		end
		
		# Check if something within #resource is already locked
		return nil if child_locked?(resource, properties[:scope])
		
		if @timeout and not properties.include?(:timeout)
			properties[:timeout] = @timeout
		end
		
		touch(resource) if (!exists?(resource))
		lock = Lock.new(resource, properties)
		lockstore[resource] = [lock, lockstore[resource]].flatten.compact

		lock
	end
	
	def unlock_all(resource)
		lockstore.delete(resource)
	end
	
	def refresh(lock)
		return if !lock.timeout || lock.timeout.downcase == 'infinite' || !@timeout
		
		lock.timeout += @timeout
	end
	
	def unlock(resource, token, uid = nil)
		locks = locked?(resource)
		Spider::Logger.debug("UNLOCKING #{resource} WITH TOKEN #{token} AND UID #{uid}")
		Spider::Logger.debug(locks)
		match = nil

		if locks
			locks.each do |lock|
				if lock.token == token and lock.uid == uid
					match = lock
					break
				end
			end
		end
		
		Spider::Logger.error("NO MATCH FOR UNLOCK!") unless match
		return false unless match
		locks.delete(match)
		
		lockstore.delete(match.resource) if locks.empty?

		true
	end
	
end
