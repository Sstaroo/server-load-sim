# Server Fleet Manager Challenge

## Overview

Manage a fleet of servers across multiple service queues with growing, stochastic demand. Balance capacity allocation, switching costs, and specialization bonuses to maximize survival time and profit.

**Time Limit:** 3 hours

## The Problem

You control up to 20 servers distributed across 3 service queues:
- **api**: Medium revenue, medium timeout tolerance
- **batch**: Low revenue, high timeout tolerance
- **premium**: High revenue, low timeout tolerance

Each queue has independent, stochastically varying demand that grows over time. You must:
1. Start/stop servers (limited to 20 total)
2. Assign servers to queues
3. Reassign servers between queues (has costs)

**Challenges:**
- Servers take time to warm up before becoming active
- Servers gain specialization bonus (up to 25% efficiency) when staying on one queue
- Switching servers between queues incurs downtime and cost, and loses specialization
- Demand shifts unpredictably between queues
- Over time, demand grows exponentially across all queues

**Game Over:**
- Any queue exceeds 500 requests → overflow
- Budget below $0 for 5 consecutive timesteps → bankruptcy

## Getting Started

1. Install dependencies:
```bash
bundle install
```

2. Implement your controller in `solution.rb`:
```ruby
def controller(state)
  # Return actions: {'start' => [...], 'stop' => [...], 'reassign' => [...]}
end
```

3. Test against a scenario:
```bash
ruby run.rb scenarios/standard.json
```

4. Evaluate against all scenarios:
```bash
ruby run.rb evaluate
```

## State Structure

Your controller receives a state hash each timestep:

```ruby
{
  timestep: 0,              # Current timestep
  budget: 200.0,            # Current budget
  max_servers: 20,          # Maximum total servers allowed

  queues: {
    'api' => {
      'size' => 0,          # Current queue size
      'demand_rate' => 10,  # Requests arriving this timestep
      'capacity' => 0,      # Current processing capacity
      'heat' => 1.0         # Demand attractiveness (0.5-1.5)
    },
    # ... 'batch', 'premium'
  },

  servers: [
    {
      'id' => 'server_001',
      'type' => 'SMALL',           # or MEDIUM, LARGE
      'queue' => 'api',            # Currently assigned queue
      'state' => 'ACTIVE',         # STARTING, ACTIVE, SWITCHING, STOPPING
      'specialization' => 0.15     # Efficiency bonus (0.0-0.25)
    },
    # ...
  ],

  config: {
    'queues' => {
      'api' => {
        'revenue_per_request' => 5,
        'timeout_threshold' => 15
      },
      # ... 'batch', 'premium'
    },
    'server_types' => {
      'SMALL' => {
        'throughput' => 5,
        'cost_per_step' => 2,
        'warmup_time' => 3,
        'startup_cost' => 10,
        'switching_time' => 3,
        'switching_cost' => 5,
        'max_specialization' => 0.15
      },
      # ... MEDIUM, LARGE
    }
  }
}
```

## Action Format

Return a hash with any of these keys (all optional):

```ruby
{
  'start' => [
    {'type' => 'SMALL', 'queue' => 'api'},
    {'type' => 'LARGE', 'queue' => 'premium'}
  ],

  'stop' => ['server_001', 'server_003'],  # Server IDs

  'reassign' => [
    {'server' => 'server_005', 'queue' => 'batch'}
  ]
}
```

## Scoring

```
score = timesteps_survived
```

The goal is to survive as long as possible before queue overflow or bankruptcy.

## Strategy Tips

- **Server types have trade-offs:**
  - SMALL: Flexible (fast warmup, cheap switching), but need many
  - LARGE: Powerful and efficient when specialized, but slow/expensive to move

- **Specialization bonus:** Servers gain up to 15-25% efficiency staying on one queue
  - Takes ~20 timesteps to fully specialize
  - Lost when switching queues

- **Capacity constraint:** You can only run 20 servers total
  - Can't just "buy more" - must make allocation trade-offs
  - Over-allocating to one queue = under-allocating to others

- **Demand signals:**
  - `heat` value shows which queues are becoming more/less attractive
  - `demand_rate` shows current incoming requests
  - Watch for growing queue sizes

- **Economic considerations:**
  - Different queues have different revenue/timeout tolerances
  - Switching has real costs (fee + downtime + specialization loss)
  - Calculate if switching benefits outweigh costs

## Important Notes

⚠️ **Your solution will be tested against hidden scenarios** with different parameters:
- Different server economics (costs, throughput, warmup times)
- Different capacity limits (may not be 20)
- Different demand patterns (volatility, growth rates, spikes)
- Different initial conditions

**Build adaptive, robust strategies** that:
- ✅ Read config parameters dynamically (don't hardcode values)
- ✅ React to observed demand patterns
- ✅ Calculate switching costs vs benefits
- ✅ Handle varying initial conditions

**Avoid brittle strategies** that:
- ❌ Assume specific queue priorities ("premium is always best")
- ❌ Hardcode server counts or types
- ❌ Ignore config parameters
- ❌ Assume fixed demand patterns

## Example: Minimal Baseline

```ruby
def controller(state)
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
```

## Project Structure

```
server-load-sim/
├── lib/
│   ├── simulator.rb           # Main simulation engine
│   ├── queue.rb              # Queue demand model
│   ├── server.rb             # Server state management
│   └── evaluator.rb          # Scoring and evaluation
├── scenarios/
│   ├── standard.json         # Balanced baseline scenario
│   ├── constrained.json      # Tighter capacity/budget limits
│   └── volatile.json         # High demand volatility
├── solution.rb               # Your implementation goes here
├── run.rb                    # Test runner
├── Gemfile
└── README.md
```

Good luck! 🚀
