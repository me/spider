# Inconsistency in IdentityMapper pks comparison. Causes the db_mapper to skip rows 
# with "Row in DB without primary keys" warnings

require 'test/unit'

class FirstModel < Spider::Model::BaseModel
    element :id, Fixnum, :primary_key => true
	element :kind, {
	    'A' => 'A',
	    'B' => 'B'
	}, :primary_key => true


end

class SecondModel < Spider::Model::BaseModel
	element :first, FirstModel, :primary_key => true, :add_multiple_reverse => :seconds

end

class TestIssue00002 < Test::Unit::TestCase

	def test_im
        first = FirstModel.new(:id => 1, :kind => 'A')
        im = Spider::Model::IdentityMapper.new
        im.put(first)
        Spider::Model.identity_mapper = im
        im.get(SecondModel, {:first => first})
	end

end