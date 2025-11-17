# Server model for tracking state, specialization, and transitions
class Server
  attr_reader :id, :type, :queue, :state, :specialization

  STATES = %w[STARTING ACTIVE SWITCHING STOPPING]

  def initialize(id, type, queue, config)
    @id = id
    @type = type
    @queue = queue
    @config = config
    @state = 'STARTING'
    @state_timer = config['warmup_time']
    @specialization = 0.0
    @time_on_queue = 0
  end

  # Update server state for this timestep
  def update(timestep)
    case @state
    when 'STARTING'
      @state_timer -= 1
      if @state_timer <= 0
        @state = 'ACTIVE'
        @state_timer = 0
      end
    when 'ACTIVE'
      # Build specialization
      @time_on_queue += 1
      max_spec = @config['max_specialization']
      # Ramp up over ~20 timesteps
      @specialization = [(@time_on_queue / 20.0) * max_spec, max_spec].min
    when 'SWITCHING'
      @state_timer -= 1
      if @state_timer <= 0
        @state = 'ACTIVE'
        @state_timer = 0
      end
    when 'STOPPING'
      @state_timer -= 1
      # Will be removed when timer reaches 0
    end
  end

  # Calculate current throughput with specialization bonus
  def throughput
    base = @config['throughput']
    @state == 'ACTIVE' ? base * (1 + @specialization) : 0
  end

  # Calculate cost per timestep
  def cost_per_step
    @state == 'ACTIVE' ? @config['cost_per_step'] : 0
  end

  # Reassign server to a new queue
  def reassign_to(new_queue)
    return false unless @state == 'ACTIVE'

    @queue = new_queue
    @state = 'SWITCHING'
    @state_timer = @config['switching_time']
    @specialization = 0.0
    @time_on_queue = 0
    true
  end

  # Stop this server
  def stop
    @state = 'STOPPING'
    @state_timer = 1
  end

  # Check if server can be removed
  def can_remove?
    @state == 'STOPPING' && @state_timer <= 0
  end

  # Get startup cost for this server type
  def self.startup_cost(config)
    config['startup_cost']
  end

  # Get switching cost for this server type
  def self.switching_cost(config)
    config['switching_cost']
  end

  # Return state as hash
  def to_h
    {
      'id' => @id,
      'type' => @type,
      'queue' => @queue,
      'state' => @state,
      'specialization' => @specialization.round(3)
    }
  end
end
