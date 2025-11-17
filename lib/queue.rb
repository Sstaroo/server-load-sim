# Queue model for managing stochastic demand and request processing
class Queue
  attr_reader :name, :size, :demand_rate, :capacity, :heat
  attr_reader :requests_completed, :requests_timed_out

  def initialize(name, config, rng)
    @name = name
    @rng = rng
    @base_rate = config['initial_rate'].to_f
    @growth_factor = config['growth_factor'].to_f
    @heat_volatility = config['heat_volatility'].to_f
    @spike_probability = config['spike_probability'].to_f
    @revenue_per_request = config['revenue_per_request'].to_f
    @timeout_threshold = config['timeout_threshold'].to_i

    @heat = 1.0
    @size = 0
    @requests = []  # Array of {arrived_at: timestep}
    @demand_rate = 0.0
    @capacity = 0.0
    @spike_remaining = 0
    @requests_completed = 0
    @requests_timed_out = 0
  end

  # Generate stochastic demand for this timestep
  def generate_demand(timestep)
    # Calculate base growth
    @base_rate *= (1 + @growth_factor)

    # Update heat (random walk, bounded 0.5-1.5)
    heat_change = @rng.rand(-@heat_volatility..@heat_volatility)
    @heat += heat_change
    @heat = [@heat, 0.5].max
    @heat = [@heat, 1.5].min

    # Check for spikes
    spike = 0.0
    if @spike_remaining > 0
      spike = @base_rate * 1.5
      @spike_remaining -= 1
    elsif @rng.rand < @spike_probability
      spike = @base_rate * 2.0
      @spike_remaining = @rng.rand(2..4)
    end

    # Combine with noise
    variation = @rng.rand(-0.15..0.15) * @base_rate
    @demand_rate = [@base_rate * @heat + variation + spike, 0].max

    # Add requests to queue
    @demand_rate.round.times do
      @requests << {arrived_at: timestep}
    end

    @size = @requests.length
  end

  # Process requests based on available capacity
  def process_requests(capacity, timestep)
    @capacity = capacity
    processed = [capacity.floor, @size].min

    revenue = 0.0
    completed = 0
    timed_out = 0

    # Process requests FIFO
    processed.times do
      request = @requests.shift
      if request
        age = timestep - request[:arrived_at]
        if age <= @timeout_threshold
          revenue += @revenue_per_request
          # Freshness bonus if processed quickly
          if age <= (@timeout_threshold * 0.5)
            revenue += (@revenue_per_request * 0.3)
          end
          completed += 1
        else
          # Already timed out, penalty
          revenue -= @revenue_per_request * 0.5
          timed_out += 1
        end
      end
    end

    # Check for timeouts in remaining queue
    @requests.reject! do |request|
      age = timestep - request[:arrived_at]
      if age > @timeout_threshold
        revenue -= @revenue_per_request * 0.5
        timed_out += 1
        true
      else
        false
      end
    end

    @size = @requests.length
    @requests_completed = completed
    @requests_timed_out = timed_out

    revenue
  end

  # Return configuration info for the state
  def config_info
    {
      'revenue_per_request' => @revenue_per_request,
      'timeout_threshold' => @timeout_threshold
    }
  end

  # Return current state info
  def to_h
    {
      'size' => @size,
      'demand_rate' => @demand_rate.round(2),
      'capacity' => @capacity.round(2),
      'heat' => @heat.round(3)
    }
  end
end
