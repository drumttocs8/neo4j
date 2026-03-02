# Neo4j with neosemantics (n10s) + APOC plugins for CIM RDF import
# Ref: https://neo4j.com/docs/operations-manual/current/docker/plugins/
#      https://neo4j.com/labs/neosemantics/installation/
#
# Strategy: Pre-seed plugin JARs at build time so the container starts
# without needing outbound HTTPS at runtime (Railway containers may
# not have reliable outbound access to GitHub releases).
# Neo4j auto-loads any JAR in /var/lib/neo4j/plugins/ on startup.

FROM neo4j:5-community

# ── Pre-seed n10s plugin at build time ───────────────────────────────
# Neo4j auto-loads any JAR in /var/lib/neo4j/plugins/ on startup.
# No NEO4J_PLUGINS env var — avoids runtime download that can hang.
ARG N10S_VERSION=5.26.0
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -fSL "https://github.com/neo4j-labs/neosemantics/releases/download/${N10S_VERSION}/neosemantics-${N10S_VERSION}.jar" \
         -o /var/lib/neo4j/plugins/neosemantics-${N10S_VERSION}.jar && \
    apt-get purge -y curl && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Do NOT set NEO4J_PLUGINS — it triggers runtime download which can
# hang if the container lacks outbound HTTPS access.

# ── Neo4j configuration ─────────────────────────────────────────────
# Enable the n10s RDF HTTP endpoint
ENV NEO4J_server_unmanaged__extension__classes=n10s.endpoint=/rdf

# Allow n10s procedures (unrestricted)
ENV NEO4J_dbms_security_procedures_unrestricted=n10s.*

# ── Networking ──────────────────────────────────────────────────────
ENV NEO4J_server_default__listen__address=0.0.0.0
ENV NEO4J_server_http_listen__address=:7474
ENV NEO4J_server_bolt_listen__address=:7687

# ── Memory ──────────────────────────────────────────────────────────
ENV NEO4J_server_memory_heap_initial__size=256m
ENV NEO4J_server_memory_heap_max__size=512m
ENV NEO4J_server_memory_pagecache_size=128m

# ── Auth ────────────────────────────────────────────────────────────
ENV NEO4J_AUTH=neo4j/verance-ai-dev

# ── Railway port routing ────────────────────────────────────────────
ENV PORT=7474
EXPOSE 7474 7687

# n10s bootstrap script (run manually after first deploy)
COPY init-n10s.sh /scripts/init-n10s.sh
RUN sed -i 's/\r$//' /scripts/init-n10s.sh && chmod +x /scripts/init-n10s.sh

# Use the default Neo4j entrypoint (no override)
