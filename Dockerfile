# Neo4j with neosemantics (n10s) for CIM RDF import
# Step 1: Get bare Neo4j running on Railway first
# Step 2: Add n10s plugin back once base works

FROM neo4j:5-community

# ── Networking ──────────────────────────────────────────────────────
ENV NEO4J_server_default__listen__address=0.0.0.0
ENV NEO4J_server_http_listen__address=:7474
ENV NEO4J_server_bolt_listen__address=:7687

# ── Memory (conservative for Railway) ──────────────────────────────
ENV NEO4J_server_memory_heap_initial__size=128m
ENV NEO4J_server_memory_heap_max__size=256m
ENV NEO4J_server_memory_pagecache_size=64m

# ── Auth ────────────────────────────────────────────────────────────
ENV NEO4J_AUTH=neo4j/verance-ai-dev

# ── Railway port routing ────────────────────────────────────────────
ENV PORT=7474
EXPOSE 7474 7687
