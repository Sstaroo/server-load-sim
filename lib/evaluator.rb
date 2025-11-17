require_relative 'simulator'

# Evaluator runs multiple scenarios and generates reports
class Evaluator
  def initialize(scenario_paths)
    @scenario_paths = scenario_paths
  end

  # Evaluate controller across all scenarios
  def evaluate(controller)
    results = []

    @scenario_paths.each do |path|
      sim = Simulator.new(path)
      score = sim.run(controller)

      results << {
        scenario: File.basename(path, '.json'),
        score: score,
        timesteps: sim.state[:timestep],
        reason: sim.state[:game_over_reason]
      }
    end

    results
  end

  # Print evaluation results
  def print_results(results)
    puts "\n" + "="*60
    puts "EVALUATION RESULTS"
    puts "="*60

    results.each do |r|
      puts "\n#{r[:scenario]}:"
      puts "  Survived: #{r[:timesteps]} timesteps"
      puts "  Ended: #{r[:reason]}" if r[:reason]
    end

    avg_score = results.sum { |r| r[:score] } / results.length.to_f
    puts "\n" + "-"*60
    puts "Average Score: #{avg_score.round(2)}"
    puts "="*60
  end
end
