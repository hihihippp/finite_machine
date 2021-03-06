# encoding: utf-8

require 'spec_helper'

describe FiniteMachine, 'async_events' do

  it 'runs events asynchronously' do
    called = []
    fsm = FiniteMachine.define do
      initial :green

      events {
        event :slow, :green => :yellow
        event :stop, :yellow => :red
        event :ready, :red    => :yellow
        event :go,    :yellow => :green
      }

      callbacks {
        on_enter :yellow do |event, a| called << "on_enter_yellow_#{a}" end
        on_enter :red    do |event, a| called << "on_enter_red_#{a}" end
      }
    end

    expect(fsm.current).to eql(:green)
    fsm.async.slow(:foo)
    fsm.event_queue.join 0.01
    expect(fsm.current).to eql(:yellow)
    expect(called).to eql([
      'on_enter_yellow_foo'
    ])
    fsm.async(:stop, :bar) # execute directly
    fsm.event_queue.join 0.01
    expect(fsm.current).to eql(:red)
    expect(called).to match_array([
      'on_enter_yellow_foo',
      'on_enter_red_bar'
    ])
  end

  it "ensure queue per thread" do
    called = []
    fsmFoo = FiniteMachine.define do
      initial :green
      events { event :slow, :green => :yellow }

      callbacks {
        on_enter :yellow do |event, a| called << "(foo)on_enter_yellow_#{a}" end
      }
    end
    fsmBar = FiniteMachine.define do
      initial :green
      events { event :slow, :green => :yellow }

      callbacks {
        on_enter :yellow do |event, a| called << "(bar)on_enter_yellow_#{a}" end
      }
    end
    foo_thread = Thread.new { fsmFoo.async.slow(:foo) }
    bar_thread = Thread.new { fsmBar.async.slow(:bar) }
    [foo_thread, bar_thread].each(&:join)
    [fsmFoo, fsmBar].each { |fsm| fsm.event_queue.join 0.02 }
    expect(called).to match_array([
      '(foo)on_enter_yellow_foo',
      '(bar)on_enter_yellow_bar'
    ])
    expect(fsmFoo.current).to eql(:yellow)
    expect(fsmBar.current).to eql(:yellow)
  end

  it "permits async callback" do
    called = []
    fsm = FiniteMachine.define do
      initial :green

      events {
        event :slow,  :green  => :yellow
        event :go,    :yellow => :green
      }

      callbacks {
        on_enter :green,  :async  do |event| called << 'on_enter_green' end
        on_enter :slow,   :async  do |event| called << 'on_enter_slow'  end
        on_exit  :yellow, :async  do |event| called << 'on_exit_yellow' end
        on_exit  :go,     :async  do |event| called << 'on_exit_go'     end
      }
    end
    fsm.slow
    fsm.go
    sleep 0.1
    expect(called).to match_array([
      'on_enter_green',
      'on_enter_slow',
      'on_exit_go',
      'on_exit_yellow'
    ])
  end
end
