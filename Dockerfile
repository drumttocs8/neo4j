# Neo4j with neosemantics (n10s) for CIM RDF import
# Ref: https://neo4j.com/docs/operations-manual/current/docker/plugins/
#      https://neo4j.com/labs/neosemantics/installation/

FROM neo4j:5-community

# ── Pre-seed n10s plugin at build time ───────────────────────────────
ARG N10S_VERSION=5.26.0
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -fSL "https://github.com/neo4j-labs/neosemantics/releases/download/${N10S_VERSION}/neosemantics-${N10S_VERSION}.jar" \
         -o /var/lib/neo4j/plugins/neosemantics-${N10S_VERSION}.jar && \
    apt-get purge -y curl && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# ── Neo4j configuration ─────────────────────────────────────────────
ENV NEO4J_server_unmanaged__extension__classes=n10s.endpoint=/rdf
ENV NEO4J_dbms_security_procedures_unrestricted=n10s.*

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

# n10s bootstrap script (run manually after first deploy)
COPY init-n10s.sh /scripts/init-n10s.sh
RUN sed -i 's/\r$//' /scripts/init-n10s.sh && chmod +x /scripts/init-n10s.sh
