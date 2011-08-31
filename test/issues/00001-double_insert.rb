require 'rr'
require 'test/unit'

extend RR::Adapters::RRMethods

class FirstModel < Spider::Model::Managed
	element :name, String


end

class SecondModel < Spider::Model::Managed
	element :name, String
	element :first, FirstModel, :integrate => true, :add_reverse => :second

end

# Mocking
require 'spiderfw/model/storage/db/db_storage'

storage = Spider::Test::DbStorage.new

FirstModel.storage = storage
SecondModel.storage = storage

$INSERTS = {}
stub(storage).execute{ |sql, *bind_vars|
	if sql =~ /INSERT INTO (\w+)/
		$INSERTS[$1] ||= 0
		$INSERTS[$1] += 1
	end
}

class TestIssue00001 < Test::Unit::TestCase

	def test_inserts
		f = FirstModel.new(:name => 'first')
		s = SecondModel.new(:name => 'second')
		s.first = f
		s.save
		$INSERTS.each do |k, v|
			assert_equal(1, v)
		end
	end

end

