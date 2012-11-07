#search_resource.rb
require 'lims-api/core_class_resource'
require 'lims-api/core_resource'
require 'lims-api/struct_stream'
module Lims::Api
  module Resources
    class SearchResource < CoreResource

      def actions
        %w(read first last)
      end

    def content_to_stream(s, mime_type)
    end

      def name
        "search"
      end
      #==================================================
      # Encoders
      #==================================================

      # Specific encoder
      module  Encoder
        include CoreResource::Encoder
        #@todo DRY with CoreClassResource
        def url_for_action(action)
          url_for(
            case action
            when "first" then "#{path}/page=1"
            when "last" then "#{path}/page=-1"
            when "read", "create" then "#{path}"
            else
              super(action)
            end
          )
        end
        def path
          object.uuid
        end
      end

      Encoders = [
        class JsonEncoder
          include Encoder
          include Lims::Api::JsonEncoder
        end
      ]
      def self.encoder_class_map 
        Encoders.mash { |k| [k::ContentType, k] }
      end
    end
  end
end