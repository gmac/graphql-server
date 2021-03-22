module GraphQLServer
  module Errors
    def graphql_error(type, message=nil, extensions:{})
      message = type.capitalize if message.nil?
      GraphQL::ExecutionError.new(
        message,
        extensions: extensions.merge({ code: type })
      )
    end

    def not_found_error(message='Record not found', key:nil)
      message += %( for "#{key}") if key.present?
      graphql_error("NOT_FOUND", message)
    end

    def user_input_error(message=nil)
      graphql_error("BAD_USER_INPUT", message)
    end

    def forbidden_error(message=nil)
      graphql_error("FORBIDDEN", message)
    end

    def unexpected_error(message=nil)
      graphql_error("UNEXPECTED", message)
    end

    # Error formatting helper for wrapping loaders that fetch records.
    # (smooths out several rough edges in the Ruby GraphQL errors implementation).
    # This method is called with a keyset to load, which is yielded to the loader block.
    # Loader results are then mapped into keyed NOT_FOUND errors for nil positions,
    # and any errors that came through in the loaded set are passed through.
    def map_errors(context, keys=nil, path: nil, nil_not_found: true)
      result = yield(keys)

      if result.is_a?(Promise)
        # context.current_path is a syncronously-modified field on context,
        # so we need to memoize a local copy to pass into the async resolution callback
        path ||= context[:current_path].dup
        return result.then { |res| map_errors(context, keys, path: path) { res } }

      elsif result.is_a?(Array) && keys.is_a?(Array)
        # An array _could_ represent a singular return value (though unlikely),
        # so check provided keys to see if they indicate this to be a list field
        map_array_errors(context, result, path: path) do |res, idx|
          res.nil? && nil_not_found ? not_found_error(key: keys[idx]) : res
        end

      else
        result.nil? && nil_not_found ? not_found_error(key: keys) : result
      end
    end

    # GraphQL Ruby doesn't natively handle array errors correctly
    # (an array with only errors nullifies the entire array result)
    # This manually performs the correct behavior...
    # errors are reported with their path, and their array position is nullified.
    def map_array_errors(context, array, path: nil)
      array.each_with_index.map do |item, idx|
        item = yield(item, idx) if block_given?
        if item.is_a?(GraphQL::ExecutionError)
          item.path = [path.presence || context[:current_path], idx].flatten
          context.add_error(item)
          nil
        else
          item
        end
      end
    end
  end
end
