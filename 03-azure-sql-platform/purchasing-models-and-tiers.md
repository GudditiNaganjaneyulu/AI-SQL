# Purchasing Models and Service Tiers

> **Why this matters:** the objective *"Recommend database configurations"* (Domain 2) often comes down to picking the right tier for a workload.

## Two purchasing models for Azure SQL Database

| Model | How you buy | Choose when |
|---|---|---|
| **vCore** (recommended) | Choose virtual cores, memory scales with them; storage billed separately | You want control, transparency, Azure Hybrid Benefit, or Hyperscale/serverless |
| **DTU** | Pre-bundled units (Basic, Standard, Premium) | Simple, small, predictable workloads |

## vCore service tiers

| Tier | Storage architecture | Strengths | Typical workload |
|---|---|---|---|
| **General Purpose** | Remote storage | Balanced, cost-effective | Most business apps |
| **Business Critical** | Local SSD + multiple replicas | Lowest latency; a **free readable secondary** for read scale-out; supports in-memory OLTP | Latency-sensitive OLTP |
| **Hyperscale** | Distributed page servers | Up to very large sizes, fast scaling, fast backups/restores, named replicas | Large or fast-growing databases |

> **In-memory OLTP** (memory-optimized tables) in Azure SQL Database needs **Business Critical** (or Premium in DTU). Remember this for *Specialized tables*.

## Compute options

| Option | Behaviour | Good for |
|---|---|---|
| **Provisioned** | Fixed vCores, always on | Steady workloads |
| **Serverless** | Auto-scales between min and max vCores; can **auto-pause** when idle (General Purpose) | Intermittent or unpredictable use, dev/test |

## Elastic pools

Many databases share one pool of resources. Ideal when you have **many databases with different peak times** (for example, one database per SaaS customer).

## Read scale-out

Business Critical and Hyperscale offer read-only replicas. Route read workloads there with the connection-string setting:

```
ApplicationIntent=ReadOnly
```

## High availability and disaster recovery (vocabulary)

| Feature | Protects against |
|---|---|
| Built-in HA (all tiers) | Node/hardware failure |
| **Zone redundancy** | Datacenter (availability zone) failure |
| **Active geo-replication / failover groups** | Region failure |
| **Point-in-time restore** (automatic backups) | Accidental data change or deletion |
| **Long-term retention** | Compliance — keep backups for years |

## Recommending a configuration — worked scenarios

| Scenario | Recommendation |
|---|---|
| Dev database used a few hours a day | General Purpose **serverless** with auto-pause |
| 300 small SaaS tenant databases | **Elastic pool** |
| Trading app needing lowest latency and a reporting replica | **Business Critical** with read scale-out |
| 40 TB and growing fast | **Hyperscale** |
| Must survive a regional outage | **Failover group** to a paired region |

## Knowledge check

1. Which tier offers a free readable secondary replica?
2. What compute option can pause when the database is idle?
3. What connection-string setting routes queries to a read replica?

<details>
<summary>Answers</summary>

1. Business Critical (Hyperscale also supports replicas).
2. Serverless.
3. `ApplicationIntent=ReadOnly`.
</details>
