require 'spiderfw'
require 'test/unit'

class TestModel < Test::Unit::TestCase
    
    def setup
#        Spider::Model.load_fixtures(Zoo.path+'/data/fixtures.yml')
    end
    
    def teardown
        # Zoo.models.each do |mod|
        #     mod.mapper.delete_all!
        # end
    end
    
    def test_load
        cat = Zoo::Animal.new('cat')
        assert_equal(cat.family.name, 'Felidae')
        dog = Zoo::Animal.new('dog')
        assert_equal(dog.family.name, 'Canidae')
    end
    
    def test_insert
        a = Zoo::Animal.new({:id => 'dodo', :name => 'Dodo', :comment => 'Extint'})
        a.insert
        loaded = Zoo::Animal.new('dodo')
        assert_equal("Dodo", loaded.name)
    end
    
    def test_identity_mapper
        a = Zoo::Animal.all
        foods = {}
        a.each do |animal|
            animal.foods.each do |food|
                foods[food.id] ||= food
                assert_equal(food.object_id, foods[food.id].object_id)
            end
        end
        cat = Zoo::Animal.new('cat')
        dog = Zoo::Animal.new('dog')
        lion = Zoo::Animal.new('lion')
        parrot = Zoo::Animal.new('parrot')
        cat.friends = [lion]
        cat.save
        lion.friends = [dog]
        lion.save
        dog.friends = [parrot]
        dog.save
        parrot.friends = [cat]
        parrot.save
        Spider::Model.with_identity_mapper do
            cat = Zoo::Animal.new('cat')
            assert_equal(cat.object_id, cat.friends[0].friends[0].friends[0].friends[0].object_id)
        end
    end
    
    def test_queryset_window
        f1 = Zoo::Food.all
        f1.order_by(:name)
        f2 = Zoo::Food.all
        f2.fetch_window = 3
        f2.order_by(:name)
        0.upto(f1.length) do |i|
            assert_equal(f1[i], f2[i])
        end
    end
        
    
end