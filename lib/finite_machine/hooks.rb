# encoding: utf-8

module FiniteMachine
  # A class reponsible for registering callbacks
  class Hooks
    include Threadable

    attr_threadsafe :collection

    # Initialize a collection of hoooks
    #
    # @example
    #   Hoosk.new(machine)
    #
    # @api public
    def initialize(machine)
      @collection = Hash.new do |events_hash, event_type|
        events_hash[event_type] = Hash.new do |state_hash, name|
          state_hash[name] = []
        end
      end
    end

    # Register callback
    #
    # @param [String] event_type
    # @param [String] name
    # @param [Proc]   callback
    #
    # @example
    #   hooks.register :enterstate, :green do ... end
    #
    # @return [Hash]
    #
    # @api public
    def register(event_type, name, callback)
      @collection[event_type][name] << callback
    end

    # Unregister callback
    #
    # @param [String] event_type
    # @param [String] name
    # @param [Proc]   callback
    #
    # @example
    #   hooks.unregister :enterstate, :green do ... end
    #
    # @return [Hash]
    #
    # @api public
    def unregister(event_type, name, callback)
      @collection[event_type][name].shift
    end

    # Return all hooks matching event and state
    #
    # @param [String] event_type
    # @param [String] event_state
    # @param [Event] event
    #
    # @example
    #   hooks.call(:entersate, :green, Event.new)
    #
    # @return [Hash]
    #
    # @api public
    def call(event_type, event_state, event)
      @collection[event_type][event_state].each do |hook|
        yield hook
      end
    end
  end # Hooks
end # FiniteMachine
