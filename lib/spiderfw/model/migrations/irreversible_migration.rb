module Spider; module Migrations

	class IrreversibleMigration < Migration
		def undo
			raise "IrreversibleMigration, can't undo"
		end
	end

end; end