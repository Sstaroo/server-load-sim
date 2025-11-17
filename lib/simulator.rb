require 'json'
require_relative 'queue'
require_relative 'server'

# Main simulation engine that runs the game loop
class Simulator
  attr_reader :state, :config, :rng

  def initialize(scenario_path)
    # Load scenario configuration
    @config = JSON.parse(File.read(scenario_path))

    # Initialize seeded random number generator
    @rng = Random.new(@config['seed'])

    # Initialize state
    @state = {
      timestep: 0,
      budget: @config['initial_budget'].to_f,
      max_servers: @config['max_servers'],
      max_queue_size: @config['max_queue_size'],
      bankruptcy_threshold: @config['bankruptcy_threshold'],
      game_over: false,
      game_over_reason: nil,
      stats: {
        'revenue_this_step' => 0.0,
        'costs_this_step' => 0.0,
        'total_revenue' => 0.0,
        'total_costs' => 0.0
      }
    }

    # Initialize queues
    @queues = {}
    @config['queues'].each do |name, queue_config|
      @queues[name] = Queue.new(name, queue_config, @rng)
    end

    # Initialize empty server list
    @servers = []
    @server_counter = 0

    # Track bankruptcy condition
    @bankruptcy_streak = 0
  end

  # Main simulation loop
  def run(controller)
    while !@state[:game_over]
      # Get actions from controller
      begin
        actions = controller.call(build_state_for_controller) || {}
      rescue => e
        warn "Controller error: #{e.message}"
        warn e.backtrace.join("\n")
        actions = {}
      end

      # Validate and apply actions
      apply_actions(actions)

      # Generate new demand
      update_demand

      # Update servers
      update_servers

      # Process queues
      process_queues

      # Check game over conditions
      check_game_over

      # Increment timestep
      @state[:timestep] += 1
    end

    # Calculate and return final score
    compute_score
  end

  private

  # Build the state object passed to the controller
  def build_state_for_controller
    queues_state = {}
    @queues.each do |name, queue|
      queues_state[name] = queue.to_h
    end

    servers_state = @servers.map(&:to_h)

    queue_configs = {}
    @queues.each do |name, queue|
      queue_configs[name] = queue.config_info
    end

    {
      timestep: @state[:timestep],
      budget: @state[:budget].round(2),
      max_servers: @state[:max_servers],
      queues: queues_state,
      servers: servers_state,
      config: {
        'queues' => queue_configs,
        'server_types' => @config['server_types']
      },
      stats: @state[:stats]
    }
  end

  # Validate and execute actions
  def apply_actions(actions)
    costs_this_step = 0.0

    # Start servers
    if actions['start']
      actions['start'].each do |start_action|
        type = start_action['type']
        queue = start_action['queue']

        # Validate
        if @servers.length >= @state[:max_servers]
          warn "Cannot start server: at max_servers limit (#{@state[:max_servers]})"
          next
        end

        unless @config['server_types'].key?(type)
          warn "Cannot start server: invalid type '#{type}'"
          next
        end

        unless @queues.key?(queue)
          warn "Cannot start server: invalid queue '#{queue}'"
          next
        end

        startup_cost = @config['server_types'][type]['startup_cost']
        if @state[:budget] < startup_cost
          warn "Cannot start server: insufficient budget (need #{startup_cost}, have #{@state[:budget].round(2)})"
          next
        end

        # Create server
        @server_counter += 1
        server_id = "server_%03d" % @server_counter
        server = Server.new(server_id, type, queue, @config['server_types'][type])
        @servers << server

        # Charge startup cost
        costs_this_step += startup_cost
      end
    end

    # Stop servers
    if actions['stop']
      actions['stop'].each do |server_id|
        server = @servers.find { |s| s.id == server_id }

        unless server
          warn "Cannot stop server: server '#{server_id}' not found"
          next
        end

        if server.state == 'STOPPING'
          warn "Cannot stop server: server '#{server_id}' already stopping"
          next
        end

        server.stop
      end
    end

    # Reassign servers
    if actions['reassign']
      actions['reassign'].each do |reassign_action|
        server_id = reassign_action['server']
        new_queue = reassign_action['queue']

        server = @servers.find { |s| s.id == server_id }

        unless server
          warn "Cannot reassign server: server '#{server_id}' not found"
          next
        end

        unless @queues.key?(new_queue)
          warn "Cannot reassign server: invalid queue '#{new_queue}'"
          next
        end

        unless server.state == 'ACTIVE'
          warn "Cannot reassign server: server '#{server_id}' not in ACTIVE state"
          next
        end

        # Charge switching cost
        switching_cost = @config['server_types'][server.type]['switching_cost']
        costs_this_step += switching_cost

        # Reassign
        server.reassign_to(new_queue)
      end
    end

    # Deduct costs from budget
    @state[:budget] -= costs_this_step
    @state[:stats]['costs_this_step'] = costs_this_step
    @state[:stats]['total_costs'] += costs_this_step
  end

  # Generate stochastic demand for all queues
  def update_demand
    @queues.each do |name, queue|
      queue.generate_demand(@state[:timestep])
    end
  end

  # Update all servers (state transitions, specialization)
  def update_servers
    # Update server states
    @servers.each do |server|
      server.update(@state[:timestep])
    end

    # Remove stopped servers
    @servers.reject! { |server| server.can_remove? }

    # Calculate operational costs
    operational_costs = @servers.sum { |server| server.cost_per_step }
    @state[:budget] -= operational_costs
    @state[:stats]['costs_this_step'] += operational_costs
    @state[:stats]['total_costs'] += operational_costs
  end

  # Process queues based on server capacity
  def process_queues
    # Calculate capacity for each queue
    queue_capacity = Hash.new(0.0)
    @servers.each do |server|
      queue_capacity[server.queue] += server.throughput
    end

    # Process requests and calculate revenue
    revenue_this_step = 0.0
    queue_capacity.each do |queue_name, capacity|
      queue = @queues[queue_name]
      revenue = queue.process_requests(capacity, @state[:timestep])
      revenue_this_step += revenue
    end

    # Update budget and stats
    @state[:budget] += revenue_this_step
    @state[:stats]['revenue_this_step'] = revenue_this_step.round(2)
    @state[:stats]['total_revenue'] += revenue_this_step
  end

  # Check for game over conditions
  def check_game_over
    # Check queue overflow
    @queues.each do |name, queue|
      if queue.size > @state[:max_queue_size]
        @state[:game_over] = true
        @state[:game_over_reason] = "queue_overflow: #{name}"
        return
      end
    end

    # Check bankruptcy
    if @state[:budget] < 0
      @bankruptcy_streak += 1
      if @bankruptcy_streak >= @state[:bankruptcy_threshold]
        @state[:game_over] = true
        @state[:game_over_reason] = 'bankruptcy'
        return
      end
    else
      @bankruptcy_streak = 0
    end
  end

  # Calculate final score
  def compute_score
    @state[:timestep]
  end
end
