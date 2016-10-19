module CrudMethods

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    def first
      r = self.api.first(self.module_name)
      new(r[0])
    end

    def all(last_modified_time = nil) #TODO Refactor into low level API
      max_records = 200
      result = []
      begin
        batch = self.api.some(self.module_name, result.count + 1, max_records, :id, :asc, last_modified_time)
        result.concat(batch) unless batch.nil?
      end until batch.nil? || (batch.length < max_records)
      result.collect { |r| new(r) }
    end

    def find(id)
      self.find_by_id(id)
    end

    def delete(id)
      self.api.delete_record(self.module_name, id)
    end

    def update(object_attribute_hash)
      raise(RuntimeError, 'No ID found', object_attribute_hash.to_s) if object_attribute_hash[:id].nil?
      id = object_attribute_hash[:id]
      object_attribute_hash.delete(:id)
      r = self.api.update_record(self.module_name, id, object_attribute_hash)
      new(object_attribute_hash.merge!(r))
    end

    def update_related(object_attribute_hash)
      raise(RuntimeError, 'No ID found', object_attribute_hash.to_s) if object_attribute_hash[:id].nil?
      id = object_attribute_hash[:id]
      object_attribute_hash.delete(:id)
      self.api.update_related_records(self.module_name, id, object_attribute_hash)
      find(id)
    end
  end

  def attach_file(file_path, file_name)
    self.api.attach_file(self.class.module_name, self.send(primary_key), file_path, file_name)
  end

  def create(object_attribute_hash)
    initialize(object_attribute_hash)
    save
  end

  def save
    h = {}
    @fields.each { |f| h.merge!({ f => eval("self.#{f.to_s}") }) }
    h.delete_if { |k, v| v.nil? }
    r = self.api.add_record(self.class.module_name, h)
    up_date(r)
  end

  def save_object(object)
    h = {}
    object.fields.each { |f| h.merge!({ f => object.send(f) }) }
    h.delete_if { |k, v| v.nil? }
    r = self.api.add_record(object.module_name, h)
    up_date(r)
  end

  def up_date(object_attribute_hash)
    update_or_create_attrs(object_attribute_hash)
    self
  end
end
