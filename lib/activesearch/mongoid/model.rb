module ActiveSearch
  module Mongoid
    class Model
      include ::Mongoid::Document
      
      field :_original_type, type: String
      field :_original_id, type: BSON::ObjectId
      field :_keywords
      field :_stored, type: Hash, default: {}
      
      index :_keywords
      index [:_original_type, :_original_id], unique: true
      
      def to_hash
        _stored
      end
      
      def store_fields(original, fields, options)
        if options && options[:store]
          self._stored = {}
          options[:store].each do |f|
            
            if original.fields[f.to_s] && original.fields[f.to_s].localized?
              self._stored[f] = original.send("#{f}_translations")
            else
              self._stored[f] = original.send(f) if original.send(f).present?
            end
          end
        end
      end
      
      def refresh_keywords(original, fields)
        self._keywords = fields.select { |f| original.fields[f.to_s]  }.inject([]) do |memo,f|
          
          if original.fields[f.to_s].localized?
            memo += original.send("#{f}_translations").map do |locale,translation|
              translation.downcase.split.map { |word| "#{locale}:#{word}"}
            end.flatten
          else
            original[f] ? memo += original[f].downcase.split : memo
          end
        end
        self._keywords = self._keywords.map! { |k| ActiveSearch.strip_tags(k) }
        self._keywords.uniq!
      end
      
      def self.deindex(original)
        ActiveSearch::Mongoid::Model.where(_original_type: original.class.to_s, _original_id: original.id).destroy
      end
      
      def self.reindex(original, fields, options)
        doc = find_or_initialize_by(_original_type: original.class.to_s, _original_id: original.id)
        doc.store_fields(original, fields, options)
        doc.refresh_keywords(original, fields)
        doc.save
      end
    end
  end
end