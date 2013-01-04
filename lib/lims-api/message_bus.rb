require 'lims-api'
require 'lims-core'

module Lims
  module Api
    # Helper functions
    module MessageBus
      class << self
        # Initialize the message bus, start it and 
        # create a channel and the exchange which will be used.
        # @param [String] environment
        def create_message_bus(env)
          config = YAML.load_file(File.join('config','amqp.yml'))[env.to_s] 
          message_bus = Lims::Core::Persistence::MessageBus.new(config)
          message_bus.connect
          message_bus.create_channel
          message_bus.prefetch(config["prefetch"])
          message_bus.topic(config["exchange"], :durable => config["durable"])
        end

        # Helper function to generate a routing key in the
        # right format. Each part of the routing key is 
        # separated with a point and each part contains only 
        # letters or numbers.
        # A routing key is build according to the following pattern:
        # study_uuid.user_uuid.model.uuid.action
        # @example
        # 555223677777.66662244900.order.1111154444555.create
        # @param [Hash] arguments
        def generate_routing_key(args)
          routing_key = ""
          %w{study_uuid user_uuid model uuid action}.each do |key|
            raise ArgumentError, "#{key} is missing to generate the routing key" unless args.include?(key.to_sym)

            routing_key << args[key.to_sym].gsub(/[^a-zA-Z0-9]/, '').downcase
            routing_key << "." 
          end
          routing_key[0..routing_key.length-2]
        end
      end
    end
  end
end
