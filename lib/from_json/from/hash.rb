module FromJson
  module From
    module Hash

      def from_json hash, original=nil
        raise InvalidArgumentError unless hash.is_a? Hash
        
        record = nil
        attributes = hash.dup

        if attributes.delete('_id') || attributes.delete('id')
          record = find(id)
          puts "[from_json]#{' -->' if original} Start import: <#{record.model_name}-#{record.to_param}>"
        else
          unique_keys = attributes.keys.select {|k| self.unique_keys.include?(k.to_sym) }
          
          base = self

          unique_keys.each do |k|
            # Base for the search: ALL records from this class

            if original.present?
              # If an original is present, scope records belonging to it alone.
              method = base.model_name.underscore.pluralize
              base = original.send(method) if original.respond_to?(method)

              # Only keep the new base if it is a criteria
              base = self unless base.respond_to? :where
            end

            value = base.respond_to?(:process_unique_key) ? base.process_unique_key(attributes[k]) : attributes[k]

            if base.is_a? Array
              puts "[from_json]#{' -->' if original} Finding #{model_name}. Trying {#{k}: #{value}} on embedded relation of size #{base.size}"
            else
              puts "[from_json]#{' -->' if original} Finding #{model_name}. Trying {#{k}: #{value}} on #{base}"
            end
            criteria = base.where(k => value)

            if criteria.size > 0
              record = criteria.first

              # Clear out duplicates - these are supposed to be unique keys!
              if criteria.size > 1
                begin
                  (criteria.to_a - [record]).each(&:destroy)
                rescue; end
                puts "[from_json] ERROR: had to prune some duplicates of #{record._id}"
              end

              puts "[from_json]#{' -->' if original} Merging with existing #{record.try(:model_name)} (id: #{record.to_param}). {#{k}: #{value}}"
              attributes.delete k
            elsif original.present?
              
              # Prune messed up/invalid records if they are attached
              invalids = base.where("#{original.model_name.underscore}_id" => original.id)
              puts "[from_json] --> Needed to remove #{invalids.size} invalid records that are attached" if invalids.size > 0
              invalids.each(&:destroy)
            end
          end

          unless record.present?
            # initialize with the first primary key
            pk = unique_keys.first
            if pk and attributes[pk]
              value = respond_to?(:process_unique_key) ? process_unique_key(attributes[pk]) : attributes[pk]
              puts "[from_json]#{' -->' if original} Finding or initializing #{base.respond_to?(:model_name) ? base.model_name : base.name} with { #{pk} => #{value} }"
              record = base.where(pk => value).first_or_initialize
            end
            record ||= new
          end
        end

        # Create/merge associations
        if defined? self::EMBEDS_MANY
          self::EMBEDS_MANY.each do |model|
            underscored = model.to_s.underscore
            attributes.delete(underscored) # We not longer support non _attributes stuff
            key = underscored + "_attributes"
            next unless attributes[key].present?
            attributes[key].each do |associated|
              klass = underscored.to_s.classify.constantize
              next if klass == self.class
              # Push an imported record onto the association
              imported = klass.from_json(associated, record)
              record.send(underscored) << imported unless imported.persisted?
            end

            # We imported this manually, so delete the _attributes value
            attributes.delete(key)
          end
        end

        # process ALL associations
        models = Array.new.tap do |m|
          #m << self::EMBEDS_ONE if defined? self::EMBEDS_ONE
          #m << self::EMBEDS_MANY if defined? self::EMBEDS_MANY
          m << self::BELONGS_TO if defined? self::BELONGS_TO
          m << self::HAS_MANY if defined? self::HAS_MANY
          m << self::HAS_ONE if defined? self::HAS_ONE
        end.flatten

        models.each do |model|
          underscored = model.to_s.underscore
          attributes.delete(underscored) # We not longer support non _attributes stuff
          key = underscored + "_attributes"
          next unless (nested = attributes[key]).present?

          nested = [ nested ] unless nested.is_a? Array

          nested.each do |item|
            klass = model.to_s.classify.constantize
            if klass != self.class and klass.respond_to? :from_json
              puts "[from_json]#{' -->' if original} Going to import #{record.model_name}'s #{klass}"
              model.to_s.classify.constantize.from_json(item, record)
            end
          end

          attributes.delete key
        end
        
        # Assign the actual attributes
        record.assign_attributes attributes.deep_reject {|k,v| v.nil? }

        # Assign associated models
        if original
          embedded_relation = original.class.embedded_relations.values.collect(&:name).include? record.model_name.pluralize.underscore.to_sym
          unless embedded_relation
            original_model = original.model_name.underscore
            original_setter = :"#{original_model}="
            
            if record.respond_to? original_setter
              # --- case 1. This record has_one of the original.

              # child.original = original
              puts "[from_json] --> #{record.model_name}.#{original_setter} <#{record.model_name}-#{record.to_param}>"
              record.send original_setter, original
            else
              # --- case 2. This record has_many of the original.
              # i.e. the original is a well and it belongs_to a field.
            
              record_model = record.model_name.underscore
              record_setter = :"#{record_model}="
              original.send record_setter, record

              puts "[from_json] --> Original #{original.model_name}.#{record_setter} <#{record.model_name}-#{record.to_param}>"

              # -- case 3. (tbd)
              # child.originals << original
              #puts "Sending #{original_model.pluralize}<< #{original.model_name} to a #{record.class.name}. #{record.inspect} #{record.persisted?} #{record.valid?} // #{original.persisted?} #{original.valid?}"
              #record.send(original_model.pluralize).send :<<, original

              # original.parent = parent
            end
          end
        end

        puts "[from_json]#{' -->' if original} Record done: <#{record.model_name}-#{record.to_param}>"
        record
      end

      def attributes_accessible model
        attr_accessible :"#{model}_attributes"
      end

      def unique_keys
        raise NotImplementedError
      end

    end
  end
end