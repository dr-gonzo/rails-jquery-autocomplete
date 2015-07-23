module RailsJQueryAutocomplete
  module Orm
    module ActiveRecord
      def active_record_get_autocomplete_order(method, options, model=nil, cast_text)
        order = options[:order]    
        table_prefix = model ? "#{model.table_name}." : ""
        order || "LOWER(#{cast_text[0]}#{table_prefix}#{method}#{cast_text[1]}) ASC"
      end

      def active_record_get_autocomplete_items(parameters)
        model     = parameters[:model]
        term      = parameters[:term]
        options   = parameters[:options]
        method    = options[:hstore] ? options[:hstore][:method] : parameters[:method]
        scopes    = Array(options[:scopes])
        where     = options[:where]
        limit     = get_autocomplete_limit(options)
        cast_text = options[:is_int] ? ['CAST(', ' AS text)'] : ['','']
        order     = active_record_get_autocomplete_order(method, options, model, cast_text)
          
        items = (::Rails::VERSION::MAJOR * 10 + ::Rails::VERSION::MINOR) >= 40 ? model.where(nil) : model.scoped

        scopes.each { |scope| items = items.send(scope) } unless scopes.empty?

        items = items.select(get_autocomplete_select_clause(model, method, options)) unless options[:full_model]
        items = items.where(get_autocomplete_where_clause(model, term, method, options, cast_text)).
            limit(limit).order(order)
        items = items.where(where) unless where.blank?

        items
      end

      def get_autocomplete_select_clause(model, method, options)
        table_name = model.table_name
        (["#{table_name}.#{model.primary_key}", "#{table_name}.#{method}"] + (options[:extra_data].blank? ? [] : options[:extra_data]))
      end

      def get_autocomplete_where_clause(model, term, method, options, cast_text)
        table_name = model.table_name
        is_full_search = options[:full]
        like_clause = (postgres?(model) ? 'ILIKE' : 'LIKE')
          
        if options[:hstore]
          ["LOWER(#{cast_text[0]}#{table_name}.#{method} -> '#{options[:hstore][:key]}'#{cast_text[1]}) LIKE ?", "#{(is_full_search ? '%' : '')}#{term.downcase}%"]
        
        else
          ["LOWER(#{cast_text[0]}#{table_name}.#{method}#{cast_text[1]}) #{like_clause} ?", "#{(is_full_search ? '%' : '')}#{term.downcase}%"]
        end
      end

      def postgres?(model)
        # Figure out if this particular model uses the PostgreSQL adapter
        model.connection.class.to_s.match(/PostgreSQLAdapter/)
      end
    end
  end
end
