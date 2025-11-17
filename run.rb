require_relative 'lib/simulator'
require_relative 'lib/evaluator'
require_relative 'solution'

if ARGV.empty?
  puts "Usage: ruby run.rb <scenario_file>"
  puts "   or: ruby run.rb evaluate"
  exit 1
end

if ARGV[0] == 'evaluate'
  # Run all provided scenarios
  scenarios = Dir['scenarios/*.json'].sort
  if scenarios.empty?
    puts "No scenario files found in scenarios/"
    exit 1
  end

  evaluator = Evaluator.new(scenarios)
  results = evaluator.evaluate(method(:controller))
  evaluator.print_results(results)
else
  # Run single scenario
  scenario = ARGV[0]
  unless File.exist?(scenario)
    puts "Error: Scenario file '#{scenario}' not found"
    exit 1
  end

  sim = Simulator.new(scenario)
  score = sim.run(method(:controller))

  puts "\n" + "="*60
  puts "SIMULATION COMPLETE"
  puts "="*60
  puts "Scenario: #{File.basename(scenario, '.json')}"
  puts "Survived: #{sim.state[:timestep]} timesteps"
  puts "Final Budget: $#{sim.state[:budget].round(2)}"
  puts "Total Revenue: $#{sim.state[:stats]['total_revenue'].round(2)}"
  puts "Total Costs: $#{sim.state[:stats]['total_costs'].round(2)}"
  puts "Total Profit: $#{(sim.state[:stats]['total_revenue'] - sim.state[:stats]['total_costs']).round(2)}"
  puts "Reason: #{sim.state[:game_over_reason]}" if sim.state[:game_over_reason]
  puts "="*60
end
