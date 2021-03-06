# encoding: utf-8

require 'set'

module FiniteMachine
  # A class responsible for observing state changes
  class Observer
    include Threadable

    # The current state machine
    attr_threadsafe :machine

    # The hooks to trigger around the transition lifecycle.
    attr_threadsafe :hooks

    # Initialize an Observer
    #
    # @api public
    def initialize(machine)
      @machine = machine
      @machine.subscribe(self)
      @hooks = FiniteMachine::Hooks.new(machine)
    end

    # Evaluate in current context
    #
    # @api private
    def call(&block)
      instance_eval(&block)
    end

    # Register callback for a given event type
    #
    # @param [Symbol, FiniteMachine::Event] event_type
    # @param [Array] args
    # @param [Proc]  callback
    #
    # @api public
    def on(event_type = Event, *args, &callback)
      sync_exclusive do
        name, async, _ = args
        name = ANY_EVENT if name.nil?
        async = false if async.nil?
        ensure_valid_callback_name!(name)
        callback.extend(Async) if async == :async
        hooks.register event_type.to_s, name, callback
      end
    end

    # Unregister callback for a given event
    #
    # @api public
    def off(event_type = ANY_EVENT, name = ANY_STATE, &callback)
      sync_exclusive do
        hooks.unregister event_type, name, callback
      end
    end

    module Once; end

    module Async; end

    def listen_on(type, *args, &callback)
      name   = args.first
      events = []
      case name
      when *state_names then events << :"#{type}state"
      when *event_names then events << :"#{type}action"
      else events << :"#{type}state" << :"#{type}action"
      end
      events.each { |event| on(Event.send(event), *args, &callback) }
    end

    def on_enter(*args, &callback)
      listen_on :enter, *args, &callback
    end

    def on_transition(*args, &callback)
      listen_on :transition, *args, &callback
    end

    def on_exit(*args, &callback)
      listen_on :exit, *args, &callback
    end

    def once_on_enter(*args, &callback)
      listen_on :enter, *args, &callback.extend(Once)
    end

    def once_on_transition(*args, &callback)
      listen_on :transition, *args, &callback.extend(Once)
    end

    def once_on_exit(*args, &callback)
      listen_on :exit, *args, &callback.extend(Once)
    end

    # Trigger all listeners
    #
    # @api public
    def trigger(event, *args, &block)
      sync_exclusive do
        [event.type, ANY_EVENT].each do |event_type|
          [event.state, ANY_STATE,
           ANY_STATE_HOOK, ANY_EVENT_HOOK].each do |event_state|
            hooks.call(event_type, event_state, event) do |hook|
              handle_callback(hook, event)
              off(event_type, event_state, &hook) if hook.is_a?(Once)
            end
          end
        end
      end
    end

    private

    # Defer callback execution
    #
    # @api private
    def defer(callable, trans_event, *data)
      async_call = AsyncCall.build(machine, callable, trans_event, *data)
      machine.event_queue << async_call
    end

    # Create callable instance
    #
    # @api private
    def create_callable(hook)
      deferred_hook = proc do |_trans_event, *_data|
        machine.instance_exec(_trans_event, *_data, &hook)
      end
      Callable.new(deferred_hook)
    end

    # Handle callback and decide if run synchronously or asynchronously
    #
    # @api private
    def handle_callback(hook, event)
      trans_event = TransitionEvent.build(event.transition)
      data        = event.data
      callable    = create_callable(hook)

      if hook.is_a?(Async)
        defer(callable, trans_event, *data)
        result = nil
      else
        result = callable.call(trans_event, *data)
      end

      event.transition.cancelled = (result == CANCELLED)
    end

    # Set of all state names
    #
    # @return [Set]
    #
    # @api private
    def state_names
      @names = Set.new
      @names.merge machine.states
      @names.merge [ANY_STATE, ANY_STATE_HOOK]
    end

    # Set of all event names
    #
    # @return [Set]
    #
    # @api private
    def event_names
      @names = Set.new
      @names.merge machine.event_names
      @names.merge [ANY_EVENT, ANY_EVENT_HOOK]
    end

    def callback_names
      state_names + event_names
    end

    def ensure_valid_callback_name!(name)
      unless callback_names.include?(name)
        exception = InvalidCallbackNameError
        machine.catch_error(exception) ||
        raise(exception, "#{name} is not a valid callback name." +
        " Valid callback names are #{callback_names.to_a.inspect}")
      end
    end

    # Forward the message to observer
    #
    # @param [String] method_name
    #
    # @param [Array] args
    #
    # @return [self]
    #
    # @api private
    def method_missing(method_name, *args, &block)
      _, event_name, callback_name = *method_name.to_s.match(/^(\w*?on_\w+?)_(\w+)$/)
      if callback_names.include?(callback_name.to_sym)
        public_send(event_name, :"#{callback_name}", *args, &block)
      else
        super
      end
    end

    # Test if a message can be handled by observer
    #
    # @param [String] method_name
    #
    # @param [Boolean] include_private
    #
    # @return [Boolean]
    #
    # @api private
    def respond_to_missing?(method_name, include_private = false)
      *_, callback_name = *method_name.to_s.match(/^(\w*?on_\w+?)_(\w+)$/)
      callback_names.include?(:"#{callback_name}")
    end
  end # Observer
end # FiniteMachine
