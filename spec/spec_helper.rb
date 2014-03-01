# encoding: utf-8

require 'finite_machine'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # Remove defined constants
  config.before :each do
    [:Car, :Logger].each do |class_name|
      if Object.const_defined?(class_name)
        Object.send(:remove_const, class_name)
      end
    end
  end
end
