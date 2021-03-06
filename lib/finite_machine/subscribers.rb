# encoding: utf-8

require 'monitor'

module FiniteMachine
  # A class responsibile for storage of event subscribers
  class Subscribers
    include Enumerable
    include MonitorMixin

    # Initialize a subscribers collection
    #
    # @api public
    def initialize(machine)
      super()
      @machine     = machine
      @subscribers = []
    end

    # Iterate over subscribers
    #
    # @api public
    def each(&block)
      @subscribers.each(&block)
    end

    # Return index of the subscriber
    #
    # @api public
    def index(subscriber)
      @subscribers.index(subscriber)
    end

    # Check if anyone is subscribed
    #
    # @return [Boolean]
    #
    # @api public
    def empty?
      @subscribers.empty?
    end

    # Add listener to subscribers
    #
    # @param [Array[#trigger]] observers
    #
    # @return [undefined]
    #
    # @api public
    def subscribe(*observers)
      synchronize do
        observers.each { |observer| @subscribers << observer }
      end
    end

    # Visit subscribers and notify
    #
    # @param [FiniteMachine::Event] event
    #
    # @return [undefined]
    #
    # @api public
    def visit(event)
      each { |subscriber| synchronize { event.notify subscriber } }
    end

    # Reset subscribers
    #
    # @return [self]
    #
    # @api public
    def reset
      @subscribers.clear
      self
    end
  end # Subscribers
end # FiniteMachine
