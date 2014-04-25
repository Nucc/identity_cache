require "test_helper"

class IndexCacheTest < IdentityCache::TestCase
  NAMESPACE = IdentityCache::CacheKeyGeneration::DEFAULT_NAMESPACE

  def setup
    super
    @record = Item.new
    @record.id = 1
    @record.title = 'bob'
    @cache_key = "#{NAMESPACE}index:Item:title:#{cache_hash(@record.title)}"
  end

  def test_fetch_with_garbage_input_should_use_properly_typed_sql
    Item.cache_index :title, :id

    Item.connection.expects(:exec_query)
      .with("SELECT id FROM `items`  WHERE `items`.`title` = 'garbage' AND `items`.`id` = 0", anything)
      .returns(ActiveRecord::Result.new([], []))

    assert_equal [], Item.fetch_by_title_and_id('garbage', 'garbage')
  end

  def test_fetch_with_unique_adds_limit_clause
    Item.cache_index :title, :id, :unique => true

    Item.connection.expects(:exec_query)
      .with("SELECT  id FROM `items`  WHERE `items`.`title` = 'title' AND `items`.`id` = 2 LIMIT 1", anything)
      .returns(ActiveRecord::Result.new([], []))

    assert_equal nil, Item.fetch_by_title_and_id('title', '2')
  end  

  def test_unique_index_caches_nil
    Item.cache_index :title, :unique => true
    assert_equal nil, Item.fetch_by_title('bob')
    assert_equal IdentityCache::CACHED_NIL, IdentityCache.cache.read(@cache_key)
  end

  def test_unique_index_expired_by_new_record
    Item.cache_index :title, :unique => true
    IdentityCache.cache.write(@cache_key, IdentityCache::CACHED_NIL)
    @record.save!
    assert_equal nil, IdentityCache.cache.read(@cache_key)
  end

  def test_unique_index_filled_on_fetch_by
    Item.cache_index :title, :unique => true
    @record.save!
    assert_equal @record, Item.fetch_by_title('bob')
    assert_equal @record.id, IdentityCache.cache.read(@cache_key)
  end

  def test_unique_index_expired_by_updated_record
    Item.cache_index :title, :unique => true
    @record.save!
    IdentityCache.cache.write(@cache_key, @record.id)

    @record.title = 'robert'
    new_cache_key = "#{NAMESPACE}index:Item:title:#{cache_hash(@record.title)}"
    IdentityCache.cache.write(new_cache_key, IdentityCache::CACHED_NIL)
    @record.save!
    assert_equal nil, IdentityCache.cache.read(@cache_key)
    assert_equal nil, IdentityCache.cache.read(new_cache_key)
  end

  def test_non_unique_index_caches_empty_result
    Item.cache_index :title
    assert_equal [], Item.fetch_by_title('bob')
    assert_equal [], IdentityCache.cache.read(@cache_key)
  end

  def test_non_unique_index_expired_by_new_record
    Item.cache_index :title
    IdentityCache.cache.write(@cache_key, [])
    @record.save!
    assert_equal nil, IdentityCache.cache.read(@cache_key)
  end

  def test_non_unique_index_filled_on_fetch_by
    Item.cache_index :title
    @record.save!
    assert_equal [@record], Item.fetch_by_title('bob')
    assert_equal [@record.id], IdentityCache.cache.read(@cache_key)
  end

  def test_non_unique_index_fetches_multiple_records
    Item.cache_index :title
    @record.save!
    record2 = Item.create(:id => 2, :title => 'bob')

    assert_equal [@record, record2], Item.fetch_by_title('bob')
    assert_equal [1, 2], IdentityCache.cache.read(@cache_key)
  end

  def test_non_unique_index_expired_by_updating_record
    Item.cache_index :title
    @record.save!
    IdentityCache.cache.write(@cache_key, [@record.id])

    @record.title = 'robert'
    new_cache_key = "#{NAMESPACE}index:Item:title:#{cache_hash(@record.title)}"
    IdentityCache.cache.write(new_cache_key, [])
    @record.save!
    assert_equal nil, IdentityCache.cache.read(@cache_key)
    assert_equal nil, IdentityCache.cache.read(new_cache_key)
  end

  def test_non_unique_index_expired_by_destroying_record
    Item.cache_index :title
    @record.save!
    IdentityCache.cache.write(@cache_key, [@record.id])
    @record.destroy
    assert_equal nil, IdentityCache.cache.read(@cache_key)
  end

  def test_set_table_name_cache_fetch
    Item.cache_index :title
    Item.table_name = 'items2'
    @record.save!
    assert_equal [@record], Item.fetch_by_title('bob')
    assert_equal [@record.id], IdentityCache.cache.read(@cache_key)
  end
end
