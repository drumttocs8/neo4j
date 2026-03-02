# Neo4j with neosemantics (n10s) plugin for RDF/CIM import
# Ref: https://neo4j.com/docs/operations-manual/current/docker/plugins/
#      https://neo4j.com/labs/neosemantics/installation/

FROM neo4j:5-community

# ── Plugin installation ─────────────────────────────────────────────
# NEO4J_PLUGINS auto-downloads at container start.
# We also pre-seed via a build-time download so Railway doesn't need
# outbound HTTPS to Github on every cold start.
ARG N10S_VERSION=5.26.0
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    curl -fSL "https://github.com/neo4j-labs/neosemantics/releases/download/${N10S_VERSION}/neosemantics-${N10S_VERSION}.jar" \
         -o /var/lib/neo4j/plugins/neosemantics-${N10S_VERSION}.jar && \
    apt-get purge -y curl && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# ── Neo4j configuration ─────────────────────────────────────────────
# Enable the n10s RDF HTTP endpoint
ENV NEO4J_server_unmanaged__extension__classes=n10s.endpoint=/rdf

# Allow n10s procedures (unrestricted)
ENV NEO4J_dbms_security_procedures_unrestricted=n10s.*

# Fallback: also declare via NEO4J_PLUGINS so the Docker entrypoint
# registers n10s even if the pre-seeded JAR version drifts
ENV NEO4J_PLUGINS='["n10s", "apoc"]'

# ── Networking ──────────────────────────────────────────────────────
# Listen on all interfaces (required for Railway / Docker networking)
ENV NEO4J_server_default__listen__address=0.0.0.0

# Bolt & HTTP on standard ports
ENV NEO4J_server_http_listen__address=:7474
ENV NEO4J_server_bolt_listen__address=:7687

# Memory tuning (Railway Small = 512 MB; adjust via Railway env vars)
ENV NEO4J_server_memory_heap_initial__size=256m
ENV NEO4J_server_memory_heap_max__size=512m
ENV NEO4J_server_memory_pagecache_size=128m

# ── Auth ────────────────────────────────────────────────────────────
# Default dev credentials — override via Railway env vars in production
# Set NEO4J_AUTH=neo4j/<password> in Railway service settings
ENV NEO4J_AUTH=neo4j/verance-ai-dev

# ── Bootstrap: auto-init n10s on first run ──────────────────────────
COPY init-n10s.sh /startup/init-n10s.sh
# Strip Windows CRLF if present, then make executable
RUN sed -i 's/\r$//' /startup/init-n10s.sh && chmod +x /startup/init-n10s.sh

EXPOSE 7474 7687

# The official entrypoint handles everything; we wrap it to run
# our one-time n10s bootstrap after the DB is ready.
CMD ["/startup/init-n10s.sh"]
