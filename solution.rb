# Implement your controller here
#
# This function is called every timestep with the current game state.
# Return a hash with actions to take (all keys optional):
#
# {
#   'start' => [
#     {'type' => 'SMALL', 'queue' => 'api'},
#     {'type' => 'LARGE', 'queue' => 'premium'}
#   ],
#   'stop' => ['server_001', 'server_003'],
#   'reassign' => [
#     {'server' => 'server_005', 'queue' => 'batch'}
#   ]
# }
#
# State structure:
# {
#   timestep: 0,              # Current timestep
#   budget: 200.0,            # Current budget
#   max_servers: 20,          # Maximum total servers allowed
#
#   queues: {
#     'api' => {
#       'size' => 0,          # Current queue size
#       'demand_rate' => 10,  # Requests arriving this timestep
#       'capacity' => 0,      # Current processing capacity
#       'heat' => 1.0         # Demand attractiveness (0.5-1.5)
#     },
#     # ... 'batch', 'premium'
#   },
#
#   servers: [
#     {
#       'id' => 'server_001',
#       'type' => 'SMALL',           # or MEDIUM, LARGE
#       'queue' => 'api',            # Currently assigned queue
#       'state' => 'ACTIVE',         # STARTING, ACTIVE, SWITCHING, STOPPING
#       'specialization' => 0.15     # Efficiency bonus (0.0-0.25)
#     },
#     # ...
#   ],
#
#   config: {
#     'queues' => {
#       'api' => {
#         'revenue_per_request' => 5,
#         'timeout_threshold' => 15
#       },
#       # ... 'batch', 'premium'
#     },
#     'server_types' => {
#       'SMALL' => {
#         'throughput' => 5,
#         'cost_per_step' => 2,
#         'warmup_time' => 3,
#         'startup_cost' => 10,
#         'switching_time' => 3,
#         'switching_cost' => 5,
#         'max_specialization' => 0.15
#       },
#       # ... MEDIUM, LARGE
#     }
#   }
# }

def controller(state)
  # Your implementation here

  # Example: Simple reactive strategy
  actions = {}

  # Find most under-capacity queue
  worst_queue = state[:queues].min_by do |name, queue|
    queue['capacity'] / [queue['demand_rate'], 1].max
  end

  # Add server if we have room and budget
  if state[:servers].length < state[:max_servers] && state[:budget] > 50
    actions['start'] = [{'type' => 'SMALL', 'queue' => worst_queue[0]}]
  end

  actions
end
